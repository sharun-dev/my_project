import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'services/firestore_service.dart';
import 'services/cloudinary_uploader.dart';
import 'models/cloudinary_upload_result.dart';
import 'chat_utilities.dart';

class ProfessionalChatScreen extends StatefulWidget {
  final String? chatId;
  final Map<String, dynamic>? professional;

  const ProfessionalChatScreen({super.key, this.chatId, this.professional});

  @override
  State<ProfessionalChatScreen> createState() => _ProfessionalChatScreenState();
}

class _ProfessionalChatScreenState extends State<ProfessionalChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _archivedChats = [];
  String _searchQuery = '';
  bool _showArchived = false;
  bool _showBlocked = false;
  String? _currentChatId;
  Stream<List<Map<String, dynamic>>>? _chatsStream;
  Stream<List<Map<String, dynamic>>>? _messagesStream;

  // Safe professional data with defaults (additional guard as helper returns
  // values that the UI expects, but we double-check here to avoid crashes).
  Map<String, dynamic> get _safeProfessional {
    final data = ChatUtilities.safeProfessionalData(widget.professional);
    return {
      'id': data['id'],
      'name': data['name'] ?? '',
      'role': data['role'] ?? '',
      'image': (data['image'] as String?)?.isNotEmpty == true
          ? data['image']
          : 'https://via.placeholder.com/100',
      'isOnline': data['isOnline'] ?? false,
      'specialization': data['specialization'] ?? '',
    };
  }

  @override
  void initState() {
    super.initState();
    _initializeChatsStream();
    // if we were passed a chatId directly, use it to load messages
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      _currentChatId = widget.chatId;
      _messagesStream = FirestoreService.getMessages(_currentChatId!);
    }
    // otherwise try to start chat based on professional data
    if (_currentChatId == null &&
        (widget.professional?.isNotEmpty ?? false) &&
        widget.professional?['id'] != FirebaseAuth.instance.currentUser?.uid) {
      _startChatWithUser();
    }
  }

  void _initializeChatsStream() {
    _chatsStream = FirestoreService.getUserChats();
  }

  Future<void> _startChatWithUser() async {
    if (_currentChatId != null) return; // already have one
    _messagesStream = Stream.value([]); // Initialize with empty stream
    try {
      final userId = widget.professional!['id'];
      print('DEBUG: Starting chat with userId: $userId');
      if (userId == null || userId.isEmpty || userId == 'default') {
        print('DEBUG: Invalid userId, cannot start chat');
        return;
      }
      _currentChatId = await FirestoreService.createOrGetChat(userId);
      print('DEBUG: Chat created/get with id: $_currentChatId');
      if (mounted) {
        _messagesStream = FirestoreService.getMessages(_currentChatId!);
        await FirestoreService.markMessagesAsRead(_currentChatId!);
        setState(() {});
      }
    } catch (e) {
      print('DEBUG: Error starting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
      }
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    print(
      'DEBUG: _sendMessage called with text: "$text", chatId: $_currentChatId',
    );
    if (text.isEmpty || _currentChatId == null) {
      print('DEBUG: Cannot send - text empty or no chatId');
      return;
    }

    try {
      await FirestoreService.sendMessage(_currentChatId!, text);
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  Future<void> _pickAndUploadFile() async {
    if (_currentChatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot send files - no chat selected')),
      );
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', // images
          'mp4', 'avi', 'mov', // videos
          'pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', // documents
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path == null) continue;

          File pickedFile = File(file.path!);
          CloudinaryUploadResult uploadResult;

          String extension = file.extension?.toLowerCase() ?? '';

          if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
            uploadResult = await CloudinaryUploader().uploadImage(
              pickedFile,
              null,
            );
          } else if (['mp4', 'avi', 'mov'].contains(extension)) {
            uploadResult = await CloudinaryUploader().uploadVideo(
              pickedFile,
              null,
            );
          } else {
            uploadResult = await CloudinaryUploader().uploadRaw(
              pickedFile,
              null,
            );
          }

          // Send the file URL as a message
          String fileType = 'document';
          if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
            fileType = 'image';
          } else if (['mp4', 'avi', 'mov'].contains(extension)) {
            fileType = 'video';
          }
          await FirestoreService.sendFileMessage(
            _currentChatId!,
            uploadResult.url,
            fileType,
          );
        }

        _scrollToBottom();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Files uploaded and sent')),
        );
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return ChatUtilities.formatTimestamp(timestamp);
    }
    if (timestamp is DateTime) {
      return ChatUtilities.formatTimestamp(Timestamp.fromDate(timestamp));
    }
    return '';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildAppBar(bool hasValidProfessional) {
    return AppBar(
      backgroundColor: const Color(0xFF1E1B2E),
      elevation: 0,
      leading: hasValidProfessional
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: hasValidProfessional
          ? Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final otherId = _safeProfessional['id'];
                    if (otherId != null && otherId != 'default') {
                      _showDetailedUserProfile(otherId);
                    }
                  },
                  child: _buildAvatarWithErrorHandling(
                    _safeProfessional['image'],
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _safeProfessional['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (_safeProfessional['specialization'] ?? '')
                                .toString()
                                .isNotEmpty
                            ? _safeProfessional['specialization']
                            : (_safeProfessional['role'] ?? ''),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Text('Chats', style: TextStyle(color: Colors.white)),
      actions: hasValidProfessional
          ? [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteChatConfirmation(),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'report') {
                    _showReportDialog(
                      _safeProfessional['name'] ?? 'Professional',
                      reportedId: _safeProfessional['id'],
                      reportType: 'user',
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.report, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Report'),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.archive, color: Colors.white),
                onPressed: _showArchivedChats,
              ),
            ],
    );
  }

  Widget _buildChatScreen() {
    return Column(
      children: [
        // Messages
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _messagesStream ?? Stream.value([]),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error loading messages: ${snapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _startChatWithUser(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!;
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No messages yet. Start the conversation!'),
                      if (_currentChatId == null) ...[
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _startChatWithUser(),
                          child: const Text('Initialize Chat'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _scrollToBottom();
                });
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _buildMessageBubble(message);
                },
              );
            },
          ),
        ),

        // Message Input
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A12),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      cursorColor: const Color(0xFFE0AAFF),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 5, 5, 5),
                      ),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: const Color.fromARGB(
                            255,
                            14,
                            13,
                            13,
                          ).withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file,
                      color: Color(0xFF9D4EDD),
                    ),
                    onPressed: _pickAndUploadFile,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9D4EDD).withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _currentChatId != null ? _sendMessage : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showArchivedChats() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Archived Chats',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _archivedChats.isEmpty
                  ? Center(
                      child: Text(
                        'No archived chats',
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _archivedChats.length,
                      itemBuilder: (context, index) {
                        final chat = _archivedChats[index];
                        return ListTile(
                          leading: SizedBox(
                            width: 40,
                            height: 40,
                            child: ClipOval(
                              child: Image.network(
                                chat['image'] ??
                                    'https://via.placeholder.com/100',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF2D2B55),
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          title: Text(
                            chat['name'],
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            chat['role'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.unarchive,
                              color: Colors.green,
                            ),
                            onPressed: () =>
                                _showFeatureComingSoon('Unarchive Chat'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeatureComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: const Color(0xFF7B2CBF),
      ),
    );
  }

  Widget _buildChatList() {
    if (_chatsStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E1B2E),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2B55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.search,
                        color: Color(0xFF9D4EDD),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search conversations...',
                            hintStyle: TextStyle(color: Color(0xFF8080A0)),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Color(0xFF8080A0),
                          ),
                          onPressed: () => setState(() => _searchQuery = ''),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2B55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Color(0xFF9D4EDD),
                    size: 20,
                  ),
                ),
                color: const Color(0xFF1E1B2E),
                onSelected: (value) {
                  setState(() {
                    if (value == 'archived') {
                      _showArchived = true;
                      _showBlocked = false;
                    } else if (value == 'blocked') {
                      _showArchived = false;
                      _showBlocked = true;
                    } else {
                      _showArchived = false;
                      _showBlocked = false;
                    }
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat,
                          color: Color(0xFF9D4EDD),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'All Chats',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9D4EDD).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '0', // Coming soon
                            style: TextStyle(
                              color: Color(0xFFE0AAFF),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archived',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.archive,
                          color: Color(0xFF9D4EDD),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Archived',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9D4EDD).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '0', // Coming soon
                            style: TextStyle(
                              color: Color(0xFFE0AAFF),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'blocked',
                    child: Row(
                      children: [
                        const Icon(Icons.block, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Blocked',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '0', // Coming soon
                            style: TextStyle(color: Colors.red, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Filter Indicators
        if (_showArchived || _showBlocked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1A162E),
            child: Row(
              children: [
                Icon(
                  _showArchived ? Icons.archive : Icons.block,
                  color: const Color(0xFFE0AAFF),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _showArchived ? 'Archived Chats' : 'Blocked Users',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showArchived = false;
                      _showBlocked = false;
                    });
                  },
                  child: const Text(
                    'Show All',
                    style: TextStyle(
                      color: Color(0xFF9D4EDD),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Chat List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final chats = snapshot.data!;
              final filteredChats = _searchQuery.isEmpty
                  ? chats
                  : chats.where((chat) {
                      final lastMessage =
                          chat['lastMessage']?.toString().toLowerCase() ?? '';
                      final query = _searchQuery.toLowerCase();
                      return lastMessage.contains(query);
                    }).toList();

              if (filteredChats.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filteredChats.length,
                itemBuilder: (context, index) {
                  final chat = filteredChats[index];
                  return _buildChatItem(chat);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showArchived
                ? Icons.archive_outlined
                : _showBlocked
                ? Icons.block_outlined
                : Icons.chat_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _showArchived
                ? 'No Archived Chats'
                : _showBlocked
                ? 'No Blocked Users'
                : _searchQuery.isNotEmpty
                ? 'No matching chats found'
                : 'No Conversations',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showArchived
                ? 'Archived chats will appear here'
                : _showBlocked
                ? 'Blocked users will appear here'
                : _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Start a conversation with someone',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final participants = ChatUtilities.extractChatParticipantIds(
      chat['participants'],
    );
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey('chat_${chat['id']}'),
      future: otherUserId.isNotEmpty
          ? FirestoreService.getUserData(otherUserId)
          : Future.value(null),
      builder: (context, snapshot) {
        final userData = snapshot.data ?? {};

        int unreadCount = 0;
        final unreadMap = chat['unreadCount'];
        if (unreadMap is Map) {
          final value = unreadMap[currentUserId];
          if (value is int) {
            unreadCount = value;
          } else if (value is num) {
            unreadCount = value.toInt();
          }
        }

        final rawLastMessageTime = chat['lastMessageTime'];
        final timeString = rawLastMessageTime != null
            ? _formatTimestamp(rawLastMessageTime)
            : '';

        return Container(
          key: ValueKey(chat['id'] ?? otherUserId),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            leading: Stack(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ClipOval(
                    child: Image.network(
                      userData['image'] ?? 'https://via.placeholder.com/100',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2D2B55),
                            border: Border.all(
                              color: (userData['isOnline'] ?? false)
                                  ? Colors.green
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.person,
                              size: 24,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (userData['isOnline'] ?? false)
                                    ? Colors.green
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: child,
                          );
                        }
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2D2B55),
                            border: Border.all(
                              color: (userData['isOnline'] ?? false)
                                  ? Colors.green
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (chat['isOnline'] == true)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                        border: Border.fromBorderSide(
                          BorderSide(color: Color(0xFF0F0F1B), width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              userData['displayName'] ??
                  userData['name'] ??
                  userData['username'] ??
                  'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              // if the record came from the users collection we prefer showing
              // specialization, otherwise fall back to role for professionals.
              (userData['type'] == 'user' &&
                      (userData['specialization'] ?? '').toString().isNotEmpty)
                  ? '${userData['specialization']} • ${chat['lastMessage'] ?? ''}'
                  : '${userData['role'] ?? 'Professional'} • ${chat['lastMessage'] ?? ''}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeString,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF9D4EDD),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfessionalChatScreen(
                    chatId: chat['id'],
                    professional: userData,
                  ),
                ),
              );
            },
            onLongPress: () => _showChatOptionsDialog(chat),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarWithErrorHandling(String imageUrl, {double radius = 20}) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2D2B55),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: radius * 1.2,
                height: radius * 1.2,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D4EDD)),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2D2B55),
              ),
              child: Center(
                child: Icon(
                  Icons.person,
                  size: radius * 1.2,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMe = message['senderId'] == currentUserId;
    final timestamp = message['timestamp'] as Timestamp?;
    final timeString = timestamp != null
        ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
        : '';
    final messageId = message['id'] ?? message.hashCode.toString();

    // For incoming messages, fetch the actual sender's data dynamically
    if (!isMe) {
      final senderId = message['senderId'] as String?;
      return FutureBuilder<Map<String, dynamic>?>(
        key: ValueKey('msg_${messageId}_${senderId}'),
        future: senderId != null
            ? FirestoreService.getUserData(senderId)
            : Future.value(null),
        builder: (context, senderSnapshot) {
          final senderData = senderSnapshot.data ?? {};
          final senderImage =
              senderData['image'] as String? ??
              'https://via.placeholder.com/100';
          final senderName =
              senderData['displayName'] ??
              senderData['name'] ??
              senderData['username'] ??
              'Unknown';

          return Container(
            key: ValueKey('container_${messageId}_incoming'),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildAvatarWithErrorHandling(senderImage, radius: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          senderName,
                          style: const TextStyle(
                            color: Color(0xFF9D4EDD),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2B55),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: const Radius.circular(4),
                            bottomRight: const Radius.circular(20),
                          ),
                        ),
                        child: message['type'] == 'file'
                            ? _buildFileMessage(message)
                            : Text(
                                message['message'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeString,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // For messages from current user
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D4EDD),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: const Radius.circular(20),
                      bottomRight: const Radius.circular(4),
                    ),
                  ),
                  child: message['type'] == 'file'
                      ? _buildFileMessage(message)
                      : Text(
                          message['message'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      timeString,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                    if (message['isRead'])
                      const Icon(
                        Icons.done_all,
                        size: 12,
                        color: Color(0xFF9D4EDD),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildFileMessage(Map<String, dynamic> message) {
    final fileUrl = message['message'] ?? '';
    final fileType = message['fileType'] ?? 'document';

    switch (fileType) {
      case 'image':
        return GestureDetector(
          onTap: () => _showFullImage(fileUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              fileUrl,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[800],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[800],
                  child: const Icon(Icons.broken_image, color: Colors.white),
                );
              },
            ),
          ),
        );
      case 'video':
        return GestureDetector(
          onTap: () => _showVideoPlayer(fileUrl),
          child: Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 50,
            ),
          ),
        );
      default: // document
        return GestureDetector(
          onTap: () => _openDocument(fileUrl),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file, color: Colors.white),
                const SizedBox(width: 8),
                Text('Document', style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
    }
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }

  void _showVideoPlayer(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot open video')));
    }
  }

  void _openDocument(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot open document')));
    }
  }

  Future<void> _showReportDialog(
    String targetName, {
    String? reportedId,
    String reportType = 'user',
  }) async {
    final reportController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          title: Text(
            'Report $targetName',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            height: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Describe the issue:',
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
              onPressed: () => Navigator.of(context).pop(),
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
                    reportedId: reportedId,
                    reportType: reportType,
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

  void _showChatOptionsDialog(Map<String, dynamic> chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildOptionItem(Icons.delete_sweep, 'Clear Chat', () {
                Navigator.pop(context);
                _showClearChatConfirmation(chat);
              }),
              _buildOptionItem(Icons.delete, 'Delete Chat', () {
                Navigator.pop(context);
                _showDeleteChatConfirmation(chat: chat);
              }),
              _buildOptionItem(
                Icons.notifications_off,
                'Mute Notifications',
                () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Muted notifications for ${chat['name']}'),
                      backgroundColor: const Color(0xFF9D4EDD),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showClearChatConfirmation(Map<String, dynamic> chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will delete all messages in this chat. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChat(chat);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteChatConfirmation({Map<String, dynamic>? chat}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Chat?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete this chat and all its messages. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chat);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChat(Map<String, dynamic> chat) async {
    try {
      final chatId = chat['id'];
      await FirestoreService.clearChatMessages(chatId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleared all messages from ${chat['name']}'),
          backgroundColor: const Color(0xFF7B2CBF),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteChat(Map<String, dynamic>? chat) async {
    try {
      final chatId = chat?['id'] ?? _currentChatId;
      if (chatId == null) {
        throw Exception('No chat selected');
      }
      await FirestoreService.deleteChat(chatId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chat != null
                ? 'Deleted chat with ${chat['name']}'
                : 'Chat deleted successfully',
          ),
          backgroundColor: const Color(0xFF7B2CBF),
        ),
      );
      // Navigate back if in detail view
      if (chat == null && mounted) {
        Navigator.pop(context);
      } else {
        // Refresh the chat list by updating state
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildOptionItem(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFE0AAFF)),
      title: Text(text, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Future<void> _showDetailedUserProfile(String userId) async {
    try {
      final userData = await FirestoreService.getUserData(userId);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1B2E),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1B2E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Profile Picture
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF9D4EDD),
                            width: 3,
                          ),
                          color: const Color(0xFF2D2B55),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            userData?['image'] ??
                                'https://via.placeholder.com/120',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF9D4EDD),
                                        ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name and Status
                    Center(
                      child: Column(
                        children: [
                          Text(
                            userData?['displayName'] ??
                                userData?['name'] ??
                                userData?['username'] ??
                                'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (userData?['isOnline'] ?? false)
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (userData?['isOnline'] ?? false)
                                    ? 'Online'
                                    : 'Offline',
                                style: TextStyle(
                                  color: (userData?['isOnline'] ?? false)
                                      ? Colors.green
                                      : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    Container(height: 1, color: Colors.white.withOpacity(0.1)),
                    const SizedBox(height: 20),

                    // Professional/Role
                    if ((userData!['specialization'] ?? '')
                            .toString()
                            .isNotEmpty ||
                        (userData['role'] ?? '').toString().isNotEmpty) ...[
                      _buildDetailItem(
                        Icons.work,
                        'Specialization',
                        (userData['specialization'] ??
                                userData['role'] ??
                                'N/A')
                            .toString(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Experience
                    if ((userData['experience'] ?? '')
                        .toString()
                        .isNotEmpty) ...[
                      _buildDetailItem(
                        Icons.history,
                        'Experience',
                        userData['experience'].toString(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Education
                    if ((userData['education'] ?? '')
                        .toString()
                        .isNotEmpty) ...[
                      _buildDetailItem(
                        Icons.school,
                        'Education',
                        userData['education'].toString(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Age & Gender
                    if ((userData['age'] ?? '').toString().isNotEmpty ||
                        (userData['gender'] ?? '').toString().isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              Icons.cake,
                              'Age',
                              userData['age'].toString(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDetailItem(
                              Icons.person,
                              'Gender',
                              userData['gender'].toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Location
                    if ((userData['location'] ?? '').toString().isNotEmpty) ...[
                      _buildDetailItem(
                        Icons.location_on,
                        'Location',
                        userData['location'].toString(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Contact
                    if ((userData['email'] ?? '').toString().isNotEmpty) ...[
                      _buildDetailItem(
                        Icons.email,
                        'Email',
                        userData['email'].toString(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if ((userData['phone'] ?? '').toString().isNotEmpty) ...[
                      _buildDetailItem(
                        Icons.phone,
                        'Phone',
                        userData['phone'].toString(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Bio
                    if ((userData['bio'] ?? '').toString().isNotEmpty) ...[
                      _buildDetailLabel('Bio'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2B55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          userData['bio'].toString(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Languages
                    if ((userData['languages'] as List<dynamic>?)?.isNotEmpty ??
                        false) ...[
                      _buildDetailLabel('Languages'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (userData['languages'] as List<dynamic>)
                            .map(
                              (lang) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9D4EDD),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  lang.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Skills
                    if ((userData['skills'] as List<dynamic>?)?.isNotEmpty ??
                        false) ...[
                      _buildDetailLabel('Skills'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (userData['skills'] as List<dynamic>)
                            .map(
                              (skill) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7B2CBF),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  skill.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Last Updated
                    if (userData['updatedAt'] != null) ...[
                      Center(
                        child: Text(
                          'Last updated: ${_formatTimestamp(userData['updatedAt'] as Timestamp)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  Widget _buildDetailLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF9D4EDD), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2B55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasValidProfessional =
        (widget.professional?.isNotEmpty ?? false) &&
        (widget.professional?['id'] ?? 'default') != 'default';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(hasValidProfessional),
      body: hasValidProfessional ? _buildChatScreen() : _buildChatList(),
    );
  }
}
