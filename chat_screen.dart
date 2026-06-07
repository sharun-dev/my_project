import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/firestore_service.dart';
import 'chat_utilities.dart';

import 'profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic>? professional;

  const ChatScreen({super.key, this.professional});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _archivedChats = [];
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  String? _currentChatId;
  Stream<List<Map<String, dynamic>>>? _chatsStream;
  Stream<List<Map<String, dynamic>>>? _messagesStream;

  // Safe professional data with defaults
  Map<String, dynamic> get _safeProfessional {
    final base = ChatUtilities.safeProfessionalData(widget.professional);
    // keep original type if provided (chat list passes it)
    if (widget.professional != null && widget.professional!['type'] != null) {
      base['type'] = widget.professional!['type'];
    }
    return base;
  }

  @override
  void initState() {
    super.initState();
    _initializeChatsStream();
    if (widget.professional != null && widget.professional!.isNotEmpty) {
      _startChatWithProfessional();
    }
  }

  void _initializeChatsStream() {
    _chatsStream = FirestoreService.getUserChats();
  }

  Future<void> _startChatWithProfessional() async {
    _messagesStream = Stream.value([]); // Initialize with empty stream
    final professionalId = widget.professional!['id'];
    print('DEBUG: Starting chat with professionalId: $professionalId');
    if (professionalId == null ||
        professionalId.isEmpty ||
        professionalId == 'default') {
      print('DEBUG: Invalid professionalId, cannot start chat');
      return;
    }
    try {
      _currentChatId = await FirestoreService.createOrGetChat(professionalId);
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

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('DEBUG: User not authenticated');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send messages')),
      );
      return;
    }

    try {
      await FirestoreService.sendMessage(_currentChatId!, text);
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('DEBUG: Error sending message: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    return ChatUtilities.formatTimestamp(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    bool hasValidProfessional =
        widget.professional != null &&
        widget.professional!.isNotEmpty &&
        widget.professional!['id'] != null &&
        widget.professional!['id'] != 'default';
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: _buildAppBar(hasValidProfessional),
      body: hasValidProfessional ? _buildChatScreen() : _buildChatList(),
    );
  }

  PreferredSizeWidget _buildAppBar(bool hasValidProfessional) {
    return AppBar(
      backgroundColor: const Color(0xFF1E1B2E),
      elevation: 2,
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
                  child: Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: NetworkImage(_safeProfessional['image']),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(
                            color: const Color(0xFF9D4EDD),
                            width: 2,
                          ),
                        ),
                      ),
                      if (_safeProfessional['isOnline'] == true)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Color(0xFF1E1B2E), width: 2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _safeProfessional['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _safeProfessional['role'],
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
          : const Row(
              children: [
                Icon(Icons.chat_rounded, color: Color(0xFFE0AAFF)),
                SizedBox(width: 8),
                Text(
                  'Messages',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
      actions: hasValidProfessional
          ? [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteChatConfirmation(),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'clear') {
                    _showClearChatConfirmation();
                  } else if (value == 'report') {
                    _showReportDialog(
                      _safeProfessional['name'] ?? 'Professional',
                      reportedId: _safeProfessional['id'],
                      reportType: 'user',
                    );
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Clear Chat'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.report, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('Report'),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          : [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  switch (value) {
                    case 'report':
                      _showReportDialog('App', reportType: 'app');
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
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
            ],
    );
  }

  Widget _buildChatList() {
    if (_chatsStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Search Bar - Always visible
        _buildSearchBar(),

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

              if (filteredChats.isEmpty && _searchQuery.isNotEmpty) {
                return _buildNoResults();
              }

              if (filteredChats.isEmpty) {
                return const Center(
                  child: Text('No chats yet. Start a conversation!'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
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

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(12),
        border: _isSearchExpanded
            ? Border.all(color: const Color(0xFF9D4EDD), width: 2)
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFFE0AAFF)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(color: Color.fromARGB(255, 14, 13, 13)),
              decoration: InputDecoration(
                hintText: 'Search messages...',
                hintStyle: TextStyle(
                  color: const Color.fromARGB(255, 7, 7, 7).withOpacity(0.7),
                ),
                border: InputBorder.none,
              ),
              onTap: () {
                setState(() {
                  _isSearchExpanded = true;
                });
              },
              onSubmitted: (value) {
                setState(() {
                  _isSearchExpanded = false;
                });
              },
            ),
          ),
          if (_isSearchExpanded || _searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () {
                setState(() {
                  _isSearchExpanded = false;
                  _searchQuery = '';
                  FocusScope.of(context).unfocus();
                });
              },
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
            Icons.search_off,
            color: const Color.fromARGB(255, 235, 2, 2).withOpacity(0.5),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No chats found',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          Text(
            'Try searching with different keywords',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
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
      future: FirestoreService.getUserData(otherUserId),
      builder: (context, snapshot) {
        // avoid showing Unknown before profile loads
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E1B2E),
                  Colors.black.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color.fromARGB(255, 16, 15, 15).withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 80, height: 16, color: Colors.grey),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final userData = snapshot.data ?? {};

        // compute a display name for both user and professional documents
        final displayName =
            userData['displayName'] ??
            userData['name'] ??
            userData['username'] ??
            'Unknown';

        final unreadCount =
            (chat['unreadCount'] as Map<String, dynamic>?)?[currentUserId] ?? 0;
        final lastMessageTime = chat['lastMessageTime'] as Timestamp?;
        final timeString = lastMessageTime != null
            ? _formatTimestamp(lastMessageTime)
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              // ignore: deprecated_member_use
              colors: [const Color(0xFF1E1B2E), Colors.black.withOpacity(0.5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (userData['id'] != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(professional: userData),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to open chat')),
                  );
                }
              },
              onLongPress: () => _showChatOptions(chat),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final otherId = userData['id'];
                        final otherType = userData['type'] ?? 'professional';
                        if (otherId != null && otherId != 'default') {
                          if (otherType == 'professional') {
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(userId: otherId),
                              ),
                            );
                          }
                        }
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: NetworkImage(
                                  userData['image'] ??
                                      'https://via.placeholder.com/100',
                                ),
                                fit: BoxFit.cover,
                              ),
                              border: Border.all(
                                color: (userData['isOnline'] ?? false)
                                    ? Colors.green
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          if ((userData['isOnline'] ?? false) == true)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(
                                    BorderSide(
                                      color: Color(0xFF1E1B2E),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                timeString,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF9D4EDD,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  // for plain users prefer a specialization badge
                                  (userData['type'] == 'user' &&
                                          (userData['specialization'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                      ? userData['specialization']
                                      : (userData['role'] ?? 'Professional'),
                                  style: const TextStyle(
                                    color: Color(0xFFE0AAFF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  chat['lastMessage'] ?? '',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE0AAFF), Color(0xFF9D4EDD)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatScreen() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _messagesStream ?? Stream.value([]),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading messages: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!;
              if (messages.isEmpty) {
                return const Center(
                  child: Text('No messages yet. Start the conversation!'),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToBottom(),
              );

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
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMe = message['senderId'] == currentUserId;
    final timestamp = message['timestamp'] as Timestamp?;
    final timeString = timestamp != null
        ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && widget.professional != null) ...[
            GestureDetector(
              onTap: () {
                final imageUrl = _safeProfessional['image'];
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: EdgeInsets.zero,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: InteractiveViewer(
                          child: Image.network(imageUrl, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  );
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(_safeProfessional['image']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF2D1B3E), Color(0xFF1E1B2E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['message'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeString,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          (message['isRead'] ?? false)
                              ? Icons.done_all
                              : Icons.done,
                          color: (message['isRead'] ?? false)
                              ? const Color.fromARGB(255, 9, 10, 10)
                              // ignore: deprecated_member_use
                              : Colors.white.withOpacity(0.5),
                          size: 12,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF7B2CBF), Color(0xFF5A189A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: const Color.fromARGB(255, 6, 5, 5).withOpacity(0.15),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      cursorColor: const Color.fromARGB(255, 8, 8, 8),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 15, 13, 13),
                      ),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        // ignore: deprecated_member_use
                        hintStyle: TextStyle(
                          color: const Color.fromARGB(
                            255,
                            18,
                            16,
                            16,
                          ).withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.send,
                color: Color.fromARGB(255, 239, 233, 233),
              ),
              onPressed: _currentChatId != null ? _sendMessage : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions(Map<String, dynamic> chat) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final participants = List<String>.from(chat['participants'] ?? []);
    participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.grey),
              title: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
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
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(chat['image']),
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
                    style: const TextStyle(
                      color: Color.fromARGB(255, 14, 14, 14),
                    ),
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

  void _showClearChatConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat?', style: TextStyle(color: Colors.white)),
        content: const Text(
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
              _clearChat();
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

  void _showDeleteChatConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Chat?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
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
              _deleteChat();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChat() async {
    if (_currentChatId == null) return;
    try {
      await FirestoreService.clearChatMessages(_currentChatId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cleared all messages from this chat'),
          backgroundColor: Color(0xFF7B2CBF),
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

  Future<void> _deleteChat() async {
    if (_currentChatId == null) return;
    try {
      await FirestoreService.deleteChat(_currentChatId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat deleted successfully'),
          backgroundColor: Color(0xFF7B2CBF),
        ),
      );
      Navigator.pop(context); // Go back after deletion
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
