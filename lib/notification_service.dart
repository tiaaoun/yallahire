import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? relatedPostId,
    String? relatedChatId,
    String? relatedPeerId,
    String? relatedPeerName,
  }) async {
    if (userId.trim().isEmpty) return;

    // keep notification creation centralized so all app flows store a consistent payload.
    await _firestore.collection('notifications').add({
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'relatedPostId': relatedPostId,
      'relatedChatId': relatedChatId,
      'relatedPeerId': relatedPeerId,
      'relatedPeerName': relatedPeerName,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> notifyAdmins({
    required String title,
    required String message,
    String? relatedPostId,
  }) async {
    // send the same moderation alert to every profile marked as an admin.
    final admins =
        await _firestore
            .collection('profiles')
            .where('isAdmin', isEqualTo: true)
            .get();

    for (final admin in admins.docs) {
      await createNotification(
        userId: admin.id,
        type: 'report_submitted',
        title: title,
        message: message,
        relatedPostId: relatedPostId,
      );
    }
  }
}
