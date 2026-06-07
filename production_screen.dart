import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/cloudinary_uploader.dart';
import 'login_page.dart';

class ProductionScreen extends StatefulWidget {
  final String uid;

  const ProductionScreen({super.key, required this.uid});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  String? _posterUrl;
  String? _posterVideoUrl;

  final TextEditingController _posterDateCtrl = TextEditingController();
  final TextEditingController _posterTimeCtrl = TextEditingController();
  final TextEditingController _posterLocationCtrl = TextEditingController();
  final TextEditingController _posterEventNameCtrl = TextEditingController();
  final TextEditingController _posterBookingLinkCtrl = TextEditingController();
  final TextEditingController _posterTicketRateCtrl = TextEditingController();
  final TextEditingController _posterDurationCtrl = TextEditingController();
  final TextEditingController _posterAboutCtrl = TextEditingController();
  bool _bookingEnabled = false;
  bool _isLoading = false;

  Future<void> _deleteEvent(String eventId) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete event: $e')));
    }
  }

  /// Fetch the actual user name or production name from Firestore.
  Future<String> _fetchUserName(String userId) async {
    try {
      // First, try to get user name from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final name =
            userDoc.data()?['name'] ??
            userDoc.data()?['username'] ??
            userDoc.data()?['displayName'];
        if (name != null && name.toString().isNotEmpty && name != 'Anonymous') {
          return name.toString();
        }
      }

      // If not found, try to get profession name from profession collection
      final profDoc = await FirebaseFirestore.instance
          .collection('profession')
          .doc(userId)
          .get();

      if (profDoc.exists) {
        final name = profDoc.data()?['name'];
        if (name != null && name.toString().isNotEmpty) {
          return name.toString();
        }
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
    }
    return 'Unknown User';
  }

  Widget _buildCreatedEventsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('producerId', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No events created yet',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final events = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final eventId = event.id;
            final eventData = event.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              color: const Color(0xFF171731),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Event ID: $eventId',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      eventData['eventName'] ?? 'Unnamed Event',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9D4EDD),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (eventData['posterUrl'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Poster',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              eventData['posterUrl'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Colors.grey.shade800,
                                  child: const Center(
                                    child: Text(
                                      'Failed to load image',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    if (eventData['posterVideoUrl'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Poster Video',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => launchUrl(
                              Uri.parse(eventData['posterVideoUrl']),
                            ),
                            child: Container(
                              height: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade900,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.play_circle_fill,
                                      color: Color(0xFF9D4EDD),
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to Play Video',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    const SizedBox(height: 8),
                    if (eventData['date'] != null)
                      Text(
                        'Date: ${eventData['date']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    if (eventData['time'] != null)
                      Text(
                        'Time: ${eventData['time']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    if (eventData['location'] != null)
                      Text(
                        'Location: ${eventData['location']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    if (eventData['duration'] != null)
                      Text(
                        'Duration: ${eventData['duration']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    const SizedBox(height: 8),
                    if (eventData['bookingLink'] != null)
                      Text(
                        'Booking Link: ${eventData['bookingLink']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    if (eventData['ticketRate'] != null)
                      Text(
                        'Ticket Rate: ${eventData['ticketRate']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    const SizedBox(height: 16),
                    // Comments Section
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventCommentsScreen(
                              eventId: eventId,
                              eventName:
                                  eventData['eventName'] ?? 'Unnamed Event',
                              isProducer: true,
                            ),
                          ),
                        );
                      },
                      child: _buildEventCommentsSummary(eventId),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF171731),
                              title: const Text(
                                'Delete Event',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: const Text(
                                'Are you sure you want to delete this event? This action cannot be undone.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteEvent(eventId);
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Delete Event'),
                      ),
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























  Widget _buildEventCommentsSummary(String eventId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF9D4EDD).withOpacity(0.2),
              ),
            ),
            child: const Text(
              'No comments yet',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Comments (${snapshot.data!.docs.length})',
                style: const TextStyle(
                  color: Color(0xFF9D4EDD),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...snapshot.data!.docs.take(5).map((commentDoc) {
                final comment = commentDoc.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (comment['userImage'] != null &&
                              comment['userImage'].toString().isNotEmpty)
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: NetworkImage(
                                comment['userImage'],
                              ),
                            )
                          else
                            const CircleAvatar(
                              radius: 12,
                              backgroundColor: Color(0xFF9D4EDD),
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FutureBuilder<String>(
                                  future: _fetchUserName(
                                    comment['userId'] ?? '',
                                  ),
                                  builder: (context, snapshot) {
                                    final displayName =
                                        snapshot.data ??
                                        (comment['userName'] ?? 'User');
                                    return Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  comment['text'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFB0B0D0),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Check for replies count
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('events')
                            .doc(eventId)
                            .collection('comments')
                            .doc(commentDoc.id)
                            .collection('replies')
                            .snapshots(),
                        builder: (context, replySnapshot) {
                          final replyCount =
                              replySnapshot.data?.docs.length ?? 0;
                          if (replyCount == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4, left: 30),
                            child: Text(
                              '$replyCount reply(ies)',
                              style: const TextStyle(
                                color: Color(0xFF9D4EDD),
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                      if (snapshot.data!.docs.indexOf(commentDoc) <
                          snapshot.data!.docs.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Divider(
                            color: Colors.white.withOpacity(0.1),
                            height: 1,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }





































  @override
  void dispose() {
    _posterDateCtrl.dispose();
    _posterTimeCtrl.dispose();
    _posterLocationCtrl.dispose();
    _posterEventNameCtrl.dispose();
    _posterBookingLinkCtrl.dispose();
    _posterTicketRateCtrl.dispose();
    _posterDurationCtrl.dispose();
    _posterAboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _uploadPoster() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);

        final file = File(result.files.single.path!);
        final uploader = CloudinaryUploader();
        final uploadResult = await uploader.uploadImage(file, (progress) {});
        final url = uploadResult.url;

        setState(() => _posterUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster uploaded successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading poster: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadPosterVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);

        final file = File(result.files.single.path!);
        final uploader = CloudinaryUploader();
        final uploadResult = await uploader.uploadVideo(file, (progress) {});
        final url = uploadResult.url;

        setState(() => _posterVideoUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster video uploaded successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading poster video: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createEvent() async {
    if (_posterEventNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final eventData = {
        'eventName': _posterEventNameCtrl.text.trim(),
        'date': _posterDateCtrl.text.trim(),
        'time': _posterTimeCtrl.text.trim(),
        'location': _posterLocationCtrl.text.trim(),
        'posterUrl': _posterUrl,
        'posterVideoUrl': _posterVideoUrl,
        'bookingLink': _bookingEnabled
            ? _posterBookingLinkCtrl.text.trim()
            : null,
        'ticketRate': _bookingEnabled
            ? _posterTicketRateCtrl.text.trim()
            : null,
        'duration': _posterDurationCtrl.text.trim(),
        'about': _posterAboutCtrl.text.trim(),
        'producerId': widget.uid,
        'likedBy': [],
        'createdAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('events').add(eventData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created successfully')),
      );
      _posterEventNameCtrl.clear();
      _posterDateCtrl.clear();
      _posterTimeCtrl.clear();
      _posterLocationCtrl.clear();
      _posterBookingLinkCtrl.clear();
      _posterTicketRateCtrl.clear();
      _posterDurationCtrl.clear();
      _posterAboutCtrl.clear();
      setState(() => _posterUrl = null);
      setState(() => _posterVideoUrl = null);
      setState(() => _bookingEnabled = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create event: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Production House Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3A227E), Color(0xFF0F0F1B)],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text(
                'LOGOUT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _logout,
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1B), Color(0xFF151522)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF171731),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(22),
                          bottomRight: Radius.circular(22),
                        ),
                      ),
                      child: const TabBar(
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          gradient: LinearGradient(
                            colors: [Color(0xFF9D4EDD), Color(0xFF6C63FF)],
                          ),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: TextStyle(fontSize: 13),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        tabs: [
                          Tab(text: 'Create'),
                          Tab(text: 'Created Events'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Create Tab
                          ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildActivityCard(
                                'Create Events, Posters and More',
                                'Create and manage events, upload posters, and handle all your production needs',
                                DefaultTabController(
                                  length: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const TabBar(
                                        indicator: BoxDecoration(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(12),
                                          ),
                                          color: Color(0xFF9D4EDD),
                                        ),
                                        labelStyle: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        labelColor: Colors.white,
                                        unselectedLabelColor: Colors.white70,
                                        tabs: [
                                          Tab(text: 'Poster'),
                                          Tab(text: 'Details'),
                                        ],
                                      ),
                                      SizedBox(
                                        height: 520,
                                        child: TabBarView(
                                          children: [
                                            ListView(
                                              padding: const EdgeInsets.only(
                                                top: 16,
                                              ),
                                              children: [
                                                if (_posterUrl != null)
                                                  Image.network(
                                                    _posterUrl!,
                                                    height: 200,
                                                    fit: BoxFit.cover,
                                                  )
                                                else
                                                  Container(
                                                    height: 200,
                                                    color: Colors.grey[300],
                                                    child: const Center(
                                                      child: Text(
                                                        'No poster uploaded',
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 16),
                                                ElevatedButton(
                                                  onPressed: _uploadPoster,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF9D4EDD),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Upload Poster',
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                ElevatedButton(
                                                  onPressed: _uploadPosterVideo,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF9D4EDD),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Upload Poster Video',
                                                  ),
                                                ),
                                                if (_posterVideoUrl !=
                                                    null) ...[
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'Video uploaded: $_posterVideoUrl',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            ListView(
                                              padding: const EdgeInsets.only(
                                                top: 16,
                                              ),
                                              children: [
                                                TextField(
                                                  controller:
                                                      _posterEventNameCtrl,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText: 'Event Name',
                                                    labelStyle: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Color(
                                                              0xFF9D4EDD,
                                                            ),
                                                          ),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                              ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                                width: 2,
                                                              ),
                                                        ),
                                                    filled: true,
                                                    fillColor: const Color(
                                                      0xFF1A1A2E,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                TextField(
                                                  controller: _posterDateCtrl,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText: 'Date',
                                                    labelStyle: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Color(
                                                              0xFF9D4EDD,
                                                            ),
                                                          ),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                              ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                                width: 2,
                                                              ),
                                                        ),
                                                    filled: true,
                                                    fillColor: const Color(
                                                      0xFF1A1A2E,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                TextField(
                                                  controller: _posterTimeCtrl,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText: 'Time',
                                                    labelStyle: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Color(
                                                              0xFF9D4EDD,
                                                            ),
                                                          ),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                              ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                                width: 2,
                                                              ),
                                                        ),
                                                    filled: true,
                                                    fillColor: const Color(
                                                      0xFF1A1A2E,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                TextField(
                                                  controller:
                                                      _posterLocationCtrl,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        'Location & Venue',
                                                    labelStyle: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Color(
                                                              0xFF9D4EDD,
                                                            ),
                                                          ),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                              ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                                width: 2,
                                                              ),
                                                        ),
                                                    filled: true,
                                                    fillColor: const Color(
                                                      0xFF1A1A2E,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                CheckboxListTile(
                                                  title: const Text(
                                                    'Booking Available',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  activeColor: const Color(
                                                    0xFF9D4EDD,
                                                  ),
                                                  value: _bookingEnabled,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _bookingEnabled =
                                                          value ?? false;
                                                    });
                                                  },
                                                ),
                                                if (_bookingEnabled) ...[
                                                  const SizedBox(height: 16),
                                                  TextField(
                                                    controller:
                                                        _posterBookingLinkCtrl,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                    decoration: InputDecoration(
                                                      labelText: 'Booking Link',
                                                      labelStyle:
                                                          const TextStyle(
                                                            color:
                                                                Colors.white70,
                                                          ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: Color(
                                                                0xFF9D4EDD,
                                                              ),
                                                            ),
                                                      ),
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            borderSide:
                                                                const BorderSide(
                                                                  color: Color(
                                                                    0xFF9D4EDD,
                                                                  ),
                                                                ),
                                                          ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            borderSide:
                                                                const BorderSide(
                                                                  color: Color(
                                                                    0xFF9D4EDD,
                                                                  ),
                                                                  width: 2,
                                                                ),
                                                          ),
                                                      filled: true,
                                                      fillColor: const Color(
                                                        0xFF1A1A2E,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  TextField(
                                                    controller:
                                                        _posterTicketRateCtrl,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                    decoration: InputDecoration(
                                                      labelText: 'Ticket Rate',
                                                      labelStyle:
                                                          const TextStyle(
                                                            color:
                                                                Colors.white70,
                                                          ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: Color(
                                                                0xFF9D4EDD,
                                                              ),
                                                            ),
                                                      ),
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            borderSide:
                                                                const BorderSide(
                                                                  color: Color(
                                                                    0xFF9D4EDD,
                                                                  ),
                                                                ),
                                                          ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            borderSide:
                                                                const BorderSide(
                                                                  color: Color(
                                                                    0xFF9D4EDD,
                                                                  ),
                                                                  width: 2,
                                                                ),
                                                          ),
                                                      filled: true,
                                                      fillColor: const Color(
                                                        0xFF1A1A2E,
                                                      ),
                                                    ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                  ),
                                                ],
                                                const SizedBox(height: 16),
                                                TextField(
                                                  controller:
                                                      _posterDurationCtrl,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText: 'Duration',
                                                    labelStyle: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Color(
                                                              0xFF9D4EDD,
                                                            ),
                                                          ),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                              ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                                width: 2,
                                                              ),
                                                        ),
                                                    filled: true,
                                                    fillColor: const Color(
                                                      0xFF1A1A2E,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                TextField(
                                                  controller: _posterAboutCtrl,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText: 'About',
                                                    labelStyle: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Color(
                                                              0xFF9D4EDD,
                                                            ),
                                                          ),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                              ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              const BorderSide(
                                                                color: Color(
                                                                  0xFF9D4EDD,
                                                                ),
                                                                width: 2,
                                                              ),
                                                        ),
                                                    filled: true,
                                                    fillColor: const Color(
                                                      0xFF1A1A2E,
                                                    ),
                                                  ),
                                                  maxLines: 3,
                                                ),
                                                const SizedBox(height: 16),
                                                ElevatedButton(
                                                  onPressed: _createEvent,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF9D4EDD),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Create Event',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Created Events Tab
                          _buildCreatedEventsList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActivityCard(String title, String description, Widget content) {
    return Card(
      elevation: 4,
      color: const Color(0xFF171731),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9D4EDD),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }
}

class EventCommentsScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final bool isProducer;

  const EventCommentsScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.isProducer,
  });

  @override
  State<EventCommentsScreen> createState() => _EventCommentsScreenState();
}

class _EventCommentsScreenState extends State<EventCommentsScreen> {
  late TextEditingController _replyController;
  String? _replyingToCommentId;
  String? _replyingToCommentAuthor;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  /// Fetch the actual user name or production name from Firestore
  Future<String> _fetchUserName(String userId) async {
    try {
      // First, try to get user name from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final name =
            userDoc.data()?['name'] ??
            userDoc.data()?['username'] ??
            userDoc.data()?['displayName'];
        if (name != null && name.toString().isNotEmpty && name != 'Anonymous') {
          return name.toString();
        }
      }

      // If not found, try to get production name from profession collection
      final profDoc = await FirebaseFirestore.instance
          .collection('profession')
          .doc(userId)
          .get();

      if (profDoc.exists) {
        final name = profDoc.data()?['name'];
        if (name != null && name.toString().isNotEmpty) {
          return name.toString();
        }
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
    return 'Unknown User';
  }

  Future<void> _addReply() async {
    if (_replyController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userName = userData.data()?['name'] ?? currentUser.email ?? 'User';
      final userImage = userData.data()?['image'] ?? '';

      // Add reply to comment
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('comments')
          .doc(_replyingToCommentId)
          .collection('replies')
          .add({
            'userId': currentUser.uid,
            'userName': userName,
            'userImage': userImage,
            'text': _replyController.text.trim(),
            'timestamp': Timestamp.now(),
            'likedBy': [],
          });

      _replyController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToCommentAuthor = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply added successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding reply: $e')));
    }
  }

  Future<void> _deleteReply(String commentId, String replyId) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId)
          .delete();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply deleted successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting reply: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1B),
        elevation: 0,
        title: Text(
          '${widget.eventName} - Comments',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .doc(widget.eventId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final commentDoc = snapshot.data!.docs[index];
                    final comment = commentDoc.data() as Map<String, dynamic>;

                    return _buildCommentCard(commentDoc.id, comment);
                  },
                );
              },
            ),
          ),
          if (_replyingToCommentId != null) _buildReplyIndicator(),
          _buildReplyInputBox(),
        ],
      ),
    );
  }

  Widget _buildCommentCard(String commentId, Map<String, dynamic> comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (comment['userImage'] != null &&
                  comment['userImage'].toString().isNotEmpty)
                CircleAvatar(
                  radius: 20,
                  backgroundImage: CachedNetworkImageProvider(
                    comment['userImage'],
                  ),
                )
              else
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF9D4EDD),
                  child: Icon(Icons.person, color: Colors.white),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: _fetchUserName(comment['userId'] ?? ''),
                      builder: (context, snapshot) {
                        final displayName =
                            snapshot.data ?? (comment['userName'] ?? 'User');
                        return Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment['text'] ?? '',
                      style: const TextStyle(
                        color: Color(0xFFB0B0D0),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Reply button
          GestureDetector(
            onTap: () {
              setState(() {
                _replyingToCommentId = commentId;
                _replyingToCommentAuthor = comment['userName'] ?? 'User';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF9D4EDD).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.reply, color: Color(0xFF9D4EDD), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Reply',
                    style: TextStyle(
                      color: Color(0xFF9D4EDD),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Replies Section
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .doc(widget.eventId)
                .collection('comments')
                .doc(commentId)
                .collection('replies')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, replySnapshot) {
              if (!replySnapshot.hasData || replySnapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(top: 12, left: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: replySnapshot.data!.docs.map((replyDoc) {
                    final reply = replyDoc.data() as Map<String, dynamic>;
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final isReplyOwner = reply['userId'] == currentUser?.uid;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171727),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF9D4EDD).withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (reply['userImage'] != null &&
                                  reply['userImage'].toString().isNotEmpty)
                                CircleAvatar(
                                  radius: 14,
                                  backgroundImage: CachedNetworkImageProvider(
                                    reply['userImage'],
                                  ),
                                )
                              else
                                const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Color(0xFF9D4EDD),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder<String>(
                                      future: _fetchUserName(
                                        reply['userId'] ?? '',
                                      ),
                                      builder: (context, snapshot) {
                                        final displayName =
                                            snapshot.data ??
                                            (reply['userName'] ?? 'User');
                                        return Row(
                                          children: [
                                            Text(
                                              displayName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF9D4EDD),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Producer',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      reply['text'] ?? '',
                                      style: const TextStyle(
                                        color: Color(0xFFB0B0D0),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isReplyOwner)
                                GestureDetector(
                                  onTap: () =>
                                      _deleteReply(commentId, replyDoc.id),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        border: Border(
          top: BorderSide(color: const Color(0xFF9D4EDD).withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Replying to $_replyingToCommentAuthor',
            style: const TextStyle(color: Color(0xFF9D4EDD), fontSize: 12),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                _replyingToCommentId = null;
                _replyingToCommentAuthor = null;
                _replyController.clear();
              });
            },
            child: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInputBox() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        border: Border(
          top: BorderSide(color: const Color(0xFF9D4EDD).withOpacity(0.2)),
        ),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              style: const TextStyle(color: Colors.white),
              maxLines: null,
              decoration: InputDecoration(
                hintText: _replyingToCommentId != null
                    ? 'Write your reply...'
                    : 'Select a comment to reply',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0xFF9D4EDD),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: const Color(0xFF9D4EDD).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0xFF9D4EDD),
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: const Color(0xFF0F0F1B),
              ),
              enabled: _replyingToCommentId != null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _replyingToCommentId != null ? _addReply : null,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _replyingToCommentId != null
                    ? const Color(0xFF9D4EDD)
                    : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
