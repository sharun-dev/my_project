import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save or update professional profile
  static Future<void> saveProfessionalProfile({
    required String role,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Prepare the data with timestamps and role
      final dataToSave = {
        'userId': userId,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ...profileData,
        // Use user-provided email if available, otherwise use auth email
        'email': (profileData['email'] as String?)?.isNotEmpty == true
            ? profileData['email']
            : _auth.currentUser?.email ?? '',
      };

      // NOTE: the collection used throughout the app is "profession" (singular).
      // earlier code accidentally referenced "professionals" which meant lookups
      // failed and navigation logic didn’t detect professional users.  Switch
      // to the correct collection name consistently.
      await _db
          .collection('profession')
          .doc(userId)
          .set(dataToSave, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error saving profile: $e');
    }
  }

  /// Fetch all professionals for a specific role
  static Future<List<Map<String, dynamic>>> fetchProfessionalsByRole(
    String role,
  ) async {
    try {
      final snapshot = await _db
          // collection name corrected
          .collection('profession')
          .where('role', isEqualTo: role)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      throw Exception('Error fetching professionals: $e');
    }
  }

  /// Fetch all professionals
  static Future<List<Map<String, dynamic>>> fetchAllProfessionals() async {
    try {
      final snapshot = await _db
          .collection('profession')
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      throw Exception('Error fetching professionals: $e');
    }
  }

  /// Stream professionals for real-time updates
  static Stream<List<Map<String, dynamic>>> streamProfessionalsByRole(
    String role,
  ) {
    return _db
        .collection('profession')
        .where('role', isEqualTo: role)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Fetch single professional by ID
  static Future<Map<String, dynamic>?> fetchProfessionalById(
    String professionalId,
  ) async {
    try {
      final doc = await _db
          .collection('profession')
          .doc(professionalId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching professional: $e');
    }
  }

  /// Fetch current user's professional profile
  static Future<Map<String, dynamic>?> fetchCurrentUserProfile() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      return await fetchProfessionalById(userId);
    } catch (e) {
      throw Exception('Error fetching current user profile: $e');
    }
  }

  /// Increment like counter for a professional and record role metadata
  static Future<void> incrementProfessionalLikes(
    String professionalId,
    String role,
  ) async {
    try {
      final safeRoleKey = role
          .replaceAll('.', '_')
          .replaceAll(r'$', '_')
          .replaceAll('/', '_')
          .replaceAll(' ', '_');

      final docRef = _db.collection('profession').doc(professionalId);

      await docRef
          .set({
            'likes': FieldValue.increment(1),
            'lastLikedRole': role,
            'likesByRole': {safeRoleKey: FieldValue.increment(1)},
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error incrementing likes: $e');
    }
  }

  /// Delete professional profile
  static Future<void> deleteProfessionalProfile(String professionalId) async {
    try {
      await _db
          .collection('professionals')
          .doc(professionalId)
          .delete()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error deleting profile: $e');
    }
  }

  /// Search professionals by name, role, or specialization
  static Future<List<Map<String, dynamic>>> searchProfessionals(
    String query,
    String role,
  ) async {
    try {
      final snapshot = await _db
          .collection('professionals')
          .where('role', isEqualTo: role)
          .get()
          .timeout(const Duration(seconds: 10));

      final queryLower = query.toLowerCase();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).where((
        professional,
      ) {
        final name = (professional['name'] as String?)?.toLowerCase() ?? '';
        final specialization =
            (professional['specialization'] as String?)?.toLowerCase() ?? '';
        return name.contains(queryLower) || specialization.contains(queryLower);
      }).toList();
    } catch (e) {
      throw Exception('Error searching professionals: $e');
    }
  }

  /// Save audition
  static Future<void> saveAudition(Map<String, dynamic> auditionData) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final dataToSave = {
        'producerId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        ...auditionData,
      };

      await _db
          .collection('Auditions')
          .add(dataToSave)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error saving audition: $e');
    }
  }

  /// Update audition by ID
  static Future<void> updateAudition(
    String auditionId,
    Map<String, dynamic> auditionData,
  ) async {
    try {
      final dataToUpdate = {
        'updatedAt': FieldValue.serverTimestamp(),
        ...auditionData,
      };

      await _db
          .collection('Auditions')
          .doc(auditionId)
          .update(dataToUpdate)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error updating audition: $e');
    }
  }

  /// Delete audition by ID
  static Future<void> deleteAudition(String auditionId) async {
    try {
      await _db
          .collection('Auditions')
          .doc(auditionId)
          .delete()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error deleting audition: $e');
    }
  }

  /// Fetch all auditions
  static Future<List<Map<String, dynamic>>> fetchAllAuditions() async {
    try {
      final snapshot = await _db
          .collection('Auditions')
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      throw Exception('Error fetching auditions: $e');
    }
  }

  /// Fetch a single audition by its ID
  static Future<Map<String, dynamic>?> fetchAuditionById(
    String auditionId,
  ) async {
    try {
      final doc = await _db
          .collection('Auditions')
          .doc(auditionId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching audition by id: $e');
    }
  }

  /// Fetch auditions by producer
  static Future<List<Map<String, dynamic>>> fetchAuditionsByProducer(
    String producerId,
  ) async {
    try {
      final snapshot = await _db
          .collection('Auditions')
          .where('producerId', isEqualTo: producerId)
          .get()
          .timeout(const Duration(seconds: 10));

      final auditions = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Sort by createdAt descending in code
      auditions.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return auditions;
    } catch (e) {
      throw Exception('Error fetching auditions: $e');
    }
  }

  /// Save audition application
  static Future<void> saveAuditionApplication(
    String auditionId,
    Map<String, dynamic> applicationData,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final dataToSave = {
        'auditionId': auditionId,
        'userId': userId,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'Applied',
        ...applicationData,
      };

      await _db
          .collection('AuditionApplications')
          .add(dataToSave)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error saving application: $e');
    }
  }

  /// Fetch applications for producer's auditions
  static Future<List<Map<String, dynamic>>> fetchApplicationsForProducer(
    String producerId,
  ) async {
    try {
      // First get producer's auditions
      final auditions = await fetchAuditionsByProducer(producerId);
      final auditionIds = auditions.map((a) => a['id']).toList();

      if (auditionIds.isEmpty) return [];

      final snapshot = await _db
          .collection('AuditionApplications')
          .where('auditionId', whereIn: auditionIds)
          .get()
          .timeout(const Duration(seconds: 10));

      final applications = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Sort by submittedAt descending in code
      applications.sort((a, b) {
        final aTime = a['submittedAt'] as Timestamp?;
        final bTime = b['submittedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return applications;
    } catch (e) {
      throw Exception('Error fetching applications: $e');
    }
  }

  /// Fetch applications for current user
  static Future<List<Map<String, dynamic>>> fetchApplicationsByUser() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _db
          .collection('AuditionApplications')
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 10));

      final applications = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Sort by submittedAt descending
      applications.sort((a, b) {
        final aTime = a['submittedAt'] as Timestamp?;
        final bTime = b['submittedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return applications;
    } catch (e) {
      throw Exception('Error fetching user applications: $e');
    }
  }

  /// Fetch auditions with user's application status
  static Future<Map<String, dynamic>> fetchAuditionsWithUserStatus() async {
    try {
      // Fetch all auditions
      final auditions = await fetchAllAuditions();

      // Fetch user's applications
      final userApplications = await fetchApplicationsByUser();

      // Create a map of auditionId to application status
      final applicationMap = {
        for (var app in userApplications) app['auditionId']: app['status'],
      };

      // Enhance auditions with application status
      final enrichedAuditions = auditions.map((audition) {
        return {
          ...audition,
          'userApplicationStatus':
              applicationMap[audition['id']] ?? 'Not Applied',
        };
      }).toList();

      return {'auditions': enrichedAuditions, 'applications': userApplications};
    } catch (e) {
      throw Exception('Error fetching auditions with user status: $e');
    }
  }

  /// Update application status
  static Future<void> updateApplicationStatus(
    String applicationId,
    String status, {
    String? message,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (message != null && message.isNotEmpty) {
        updateData['acceptanceMessage'] = message;
      }
      await _db
          .collection('AuditionApplications')
          .doc(applicationId)
          .update(updateData)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error updating application status: $e');
    }
  }

  static Future<void> updateApplicationStatusWithReason(
    String applicationId,
    String status,
    String rejectionReason,
    String rejectionComment,
  ) async {
    try {
      await _db
          .collection('AuditionApplications')
          .doc(applicationId)
          .update({
            'status': status,
            'rejectionReason': rejectionReason,
            'rejectionComment': rejectionComment,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error updating application status: $e');
    }
  }

  /// Create or get existing chat between two users
  static Future<String> createOrGetChat(String otherUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Generate deterministic chat ID based on sorted user IDs
      final ids = [currentUserId, otherUserId]..sort();
      final chatId = ids.join('_');

      // Check if deterministic chat already exists
      final docRef = _db.collection('chats').doc(chatId);
      final doc = await docRef.get();
      if (doc.exists) {
        return chatId;
      }

      // Fallback: check for an existing legacy chat document created with auto-generated ID
      final existingSnapshot = await _db
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? existingChat;
      for (var doc in existingSnapshot.docs) {
        final participants = List<String>.from(
          doc.data()['participants'] ?? [],
        );
        if (participants.contains(otherUserId) && participants.length == 2) {
          existingChat = doc;
          break;
        }
      }

      if (existingChat != null) {
        return existingChat.id;
      }

      // Create new chat using deterministic ID
      final chatData = {
        'participants': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
        'unreadCount': {currentUserId: 0, otherUserId: 0},
      };

      await docRef.set(chatData);
      return chatId;
    } catch (e) {
      throw Exception('Error creating/getting chat: $e');
    }
  }

  /// Send message in a chat
  static Future<void> sendMessage(String chatId, String message) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      print(
        'DEBUG: sendMessage - currentUserId: $currentUserId, chatId: $chatId, message: $message',
      );
      if (currentUserId == null) throw Exception('User not authenticated');

      final messageData = {
        'senderId': currentUserId,
        'message': message,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Add message to subcollection
      print('DEBUG: Adding message to subcollection');
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat's last message
      print('DEBUG: Updating last message');
      await _db.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
      });

      // Update unread count for other participant
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      final participants = List<String>.from(
        chatDoc.data()?['participants'] ?? [],
      );
      final otherUserId = participants.firstWhere((id) => id != currentUserId);

      print('DEBUG: Updating unread count for $otherUserId');
      await _db.collection('chats').doc(chatId).update({
        'unreadCount.$otherUserId': FieldValue.increment(1),
      });
      print('DEBUG: Message sent successfully');
    } catch (e) {
      print('DEBUG: Error in sendMessage: $e');
      throw Exception('Error sending message: $e');
    }
  }

  /// Send file message in a chat
  static Future<void> sendFileMessage(
    String chatId,
    String fileUrl,
    String fileType,
  ) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      print(
        'DEBUG: sendFileMessage - currentUserId: $currentUserId, chatId: $chatId, fileUrl: $fileUrl, fileType: $fileType',
      );
      if (currentUserId == null) throw Exception('User not authenticated');

      final messageData = {
        'senderId': currentUserId,
        'message': fileUrl,
        'type': 'file',
        'fileType': fileType,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Add message to subcollection
      print('DEBUG: Adding file message to subcollection');
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat's last message
      print('DEBUG: Updating last message for file');
      await _db.collection('chats').doc(chatId).update({
        'lastMessage': 'File: $fileType',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
      });

      // Update unread count for other participant
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      final participants = List<String>.from(
        chatDoc.data()?['participants'] ?? [],
      );
      final otherUserId = participants.firstWhere((id) => id != currentUserId);

      print('DEBUG: Updating unread count for $otherUserId');
      await _db.collection('chats').doc(chatId).update({
        'unreadCount.$otherUserId': FieldValue.increment(1),
      });
      print('DEBUG: File message sent successfully');
    } catch (e) {
      print('DEBUG: Error in sendFileMessage: $e');
      throw Exception('Error sending file message: $e');
    }
  }

  /// Get messages for a chat
  static Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          // Sort by timestamp ascending (oldest first)
          messages.sort((a, b) {
            final aTime = a['timestamp'];
            final bTime = b['timestamp'];

            DateTime? aDate;
            DateTime? bDate;

            if (aTime is Timestamp) {
              aDate = aTime.toDate();
            } else if (aTime is DateTime) {
              aDate = aTime;
            }

            if (bTime is Timestamp) {
              bDate = bTime.toDate();
            } else if (bTime is DateTime) {
              bDate = bTime;
            }

            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return aDate.compareTo(bDate);
          });
          return messages;
        });
  }

  /// Get chats for current user
  static Stream<List<Map<String, dynamic>>> getUserChats() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _db
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Mark messages as read in a chat
  static Future<void> markMessagesAsRead(String chatId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Reset unread count
      await _db.collection('chats').doc(chatId).update({
        'unreadCount.$currentUserId': 0,
      });

      // Mark all messages from other user as read
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      final participants = List<String>.from(
        chatDoc.data()?['participants'] ?? [],
      );
      final otherUserId = participants.firstWhere((id) => id != currentUserId);

      final messages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Error marking messages as read: $e');
    }
  }

  /// Get user data by ID (for chat participants)
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      // first check the singular "profession" collection that the app
      // currently writes when a professional registers/logs in.  We keep the
      // older plural form as a fallback in case any legacy documents exist.
      var doc = await _db.collection('profession').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final displayName =
            data['username'] ??
            data['name'] ??
            data['fullName'] ??
            'Unknown User';
        return {
          'id': doc.id,
          'type': 'professional',
          'name': data['name'] ?? data['fullName'] ?? 'Unknown User',
          'displayName': displayName,
          ...data,
        };
      }

      // fallback to old collection name in case some records still use it
      doc = await _db.collection('professionals').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final displayName =
            data['username'] ??
            data['name'] ??
            data['fullName'] ??
            'Unknown User';
        return {
          'id': doc.id,
          'type': 'professional',
          'name': data['name'] ?? data['fullName'] ?? 'Unknown User',
          'displayName': displayName,
          ...data,
        };
      }

      // Then try users collection (if exists)
      doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final displayName =
            data['username'] ??
            data['name'] ??
            data['fullName'] ??
            'Unknown User';
        return {
          'id': doc.id,
          'type': 'user',
          'name': displayName,
          'displayName': displayName,
          'username': data['username'],
          'specialization': data['specialization'],
          ...data,
        };
      }

      return null;
    } catch (e) {
      throw Exception('Error getting user data: $e');
    }
  }

  /// Fetch chat document by ID
  static Future<Map<String, dynamic>?> getChatById(String chatId) async {
    try {
      final doc = await _db.collection('chats').doc(chatId).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }
      return null;
    } catch (e) {
      throw Exception('Error getting chat data: $e');
    }
  }

  /// Submit a report
  static Future<void> submitReport({
    required String message,
    String? reportedId,
    String? reportType, // 'user' or 'app'
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');

      final reportData = {
        'reporterId': currentUserId,
        'reportedId': reportedId,
        'message': message,
        'reportType': reportType ?? 'user',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // for admin to review
      };

      await _db
          .collection('reports')
          .add(reportData)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error submitting report: $e');
    }
  }

  /// Clear all messages from a chat (keeps the chat)
  static Future<void> clearChatMessages(String chatId) async {
    try {
      final messages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get()
          .timeout(const Duration(seconds: 10));

      final batch = _db.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Reset last message
      await _db.collection('chats').doc(chatId).update({
        'lastMessage': null,
        'lastMessageTime': null,
        'lastMessageSender': null,
      });
    } catch (e) {
      throw Exception('Error clearing chat messages: $e');
    }
  }

  /// Delete a chat completely (including all messages)
  static Future<void> deleteChat(String chatId) async {
    try {
      // First delete all messages in the chat
      final messages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get()
          .timeout(const Duration(seconds: 10));

      final batch = _db.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      // Then delete the chat document itself
      batch.delete(_db.collection('chats').doc(chatId));
      await batch.commit();
    } catch (e) {
      throw Exception('Error deleting chat: $e');
    }
  }

  /// Fetch live sessions by creator
  static Future<List<Map<String, dynamic>>> fetchLiveSessionsByCreator(
    String creatorId,
  ) async {
    try {
      final snapshot = await _db
          .collection('events')
          .where('creatorId', isEqualTo: creatorId)
          .get()
          .timeout(const Duration(seconds: 10));

      final sessions = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((session) => session['eventType'] == 'Live Session')
          .toList();

      sessions.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return sessions;
    } catch (e) {
      throw Exception('Error fetching live sessions: $e');
    }
  }

  /// Delete live session
  static Future<void> deleteLiveSession(String sessionId) async {
    try {
      await _db
          .collection('events')
          .doc(sessionId)
          .delete()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error deleting live session: $e');
    }
  }

  /// Add comment to live session
  static Future<void> addComment(String eventId, String comment) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final userDoc = await _db.collection('users').doc(userId).get();
      final userName = userDoc.data()?['name'] ?? userDoc.data()?['username'] ?? '';
      final userImage = userDoc.data()?['image'] ?? '';

      await _db.collection('events').doc(eventId).collection('comments').add({
        'userId': userId,
        'userName': userName,
        'userImage': userImage,
        'text': comment,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
        'likedBy': [],
      });
    } catch (e) {
      throw Exception('Error adding comment: $e');
    }
  }

  /// Get comments for live session
  static Stream<List<Map<String, dynamic>>> getComments(String eventId) {
    return _db
        .collection('events')
        .doc(eventId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Delete comment from live session
  static Future<void> deleteComment(String eventId, String commentId) async {
    try {
      await _db
          .collection('events')
          .doc(eventId)
          .collection('comments')
          .doc(commentId)
          .delete()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('Error deleting comment: $e');
    }
  }

}
