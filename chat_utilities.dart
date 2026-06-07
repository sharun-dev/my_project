import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for chat-related functions
class ChatUtilities {
  /// Format timestamp to readable format
  static String formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays == 0) {
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
    }
  }

  /// Validate professional data for chat
  static bool isValidProfessional(Map<String, dynamic>? professional) {
    if (professional == null || professional.isEmpty) return false;
    final id = professional['id'];
    return id != null &&
        id != 'default' &&
        (id is String ? id.isNotEmpty : true);
  }

  /// Safely extract professional or user data
  ///
  /// The chat screens originally were written around professionals, but we now
  /// support chatting with plain users stored in the `users` collection.  The
  /// helper ensures there are always some common fields available and provides
  /// sensible fallbacks (username for name, etc.).  It also exposes
  /// `specialization` if present so the UI can render it.
  static Map<String, dynamic> safeProfessionalData(
    Map<String, dynamic>? professional,
  ) {
    if (professional == null || professional.isEmpty) {
      // return safe defaults that won't crash UI components
      return {
        'id': null,
        'name': '',
        'role': '',
        'image': 'https://via.placeholder.com/100',
        'isOnline': false,
        'specialization': '',
        'displayName': '',
      };
    }
    // prefer displayName then username when available, otherwise name
    final name =
        professional['displayName'] ??
        professional['username'] ??
        professional['name'];
    return {
      'id': professional['id'],
      'name': name ?? '',
      'displayName': name ?? '',
      'role': professional['role'] ?? '',
      'image': professional['image'] ?? 'https://via.placeholder.com/100',
      'isOnline': professional['isOnline'] ?? false,
      'specialization': professional['specialization'] ?? '',
      // preserve the original type (may be 'professional' or 'user') so callers
      // can decide which profile screen to show
      'type': professional['type'] ?? 'professional',
    };
  }

  /// Normalize different chat participant storage formats to string IDs.
  static List<String> extractChatParticipantIds(dynamic participantsRaw) {
    if (participantsRaw is List) {
      final ids = <String>{};
      for (final participant in participantsRaw) {
        if (participant is String) {
          if (participant.isNotEmpty) ids.add(participant);
        } else if (participant is Map<String, dynamic>) {
          final id =
              participant['id'] ??
              participant['userId'] ??
              participant['uid'] ??
              participant['participantId'];
          if (id is String && id.isNotEmpty) ids.add(id);
        } else if (participant is DocumentReference) {
          ids.add(participant.id);
        }
      }
      return ids.toList();
    }
    return <String>[];
  }
}
