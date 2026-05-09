import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'dashboard_screen.dart';
import 'reports_review_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const Color kPrimary = Color(0xFFE89C8A);

  String _timeAgo(Timestamp? createdAt) {
    if (createdAt == null) return '';
    final now = DateTime.now();
    final date = createdAt.toDate();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'application_received':
        return Icons.assignment_ind_outlined;
      case 'application_accepted':
        return Icons.check_circle_outline;
      case 'application_rejected':
        return Icons.cancel_outlined;
      case 'service_requested':
        return Icons.handshake_outlined;
      case 'new_message':
        return Icons.chat_bubble_outline;
      case 'completion_request':
        return Icons.task_alt_outlined;
      case 'review_reminder':
        return Icons.rate_review_outlined;
      case 'report_submitted':
        return Icons.flag_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Future<void> _handleTap(
    BuildContext context,
    QueryDocumentSnapshot notificationDoc,
  ) async {
    final data = notificationDoc.data() as Map<String, dynamic>;

    // mark the notification as read before routing the user to the related screen.
    await notificationDoc.reference.update({'isRead': true});
    if (!context.mounted) return;

    final type = (data['type'] ?? '').toString();
    final relatedPeerId = (data['relatedPeerId'] ?? '').toString();
    final relatedPeerName = (data['relatedPeerName'] ?? 'User').toString();

    if (type == 'new_message' && relatedPeerId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  ChatScreen(peerId: relatedPeerId, peerName: relatedPeerName),
        ),
      );
      return;
    }

    if (type == 'report_submitted') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReportsReviewScreen()),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen(initialIndex: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body:
          user == null
              ? const Center(
                child: Text(
                  'Please log in to view notifications.',
                  style: TextStyle(fontSize: 16),
                ),
              )
              : StreamBuilder<QuerySnapshot>(
                // stream the user's notifications in reverse chronological order.
                stream:
                    FirebaseFirestore.instance
                        .collection('notifications')
                        .where('userId', isEqualTo: user.uid)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: kPrimary),
                    );
                  }

                  final notifications = snapshot.data?.docs ?? [];

                  if (notifications.isEmpty) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBFA),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFF2DFDA)),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              color: Color(0xFFB86E5D),
                              size: 34,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No notifications yet.',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Important activity related to your posts, requests, chats, and reviews will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final doc = notifications[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isRead = data['isRead'] == true;
                      final createdAt = data['createdAt'] as Timestamp?;
                      final type = (data['type'] ?? '').toString();

                      return InkWell(
                        onTap: () => _handleTap(context, doc),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                isRead ? Colors.white : const Color(0xFFFFFBFA),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  isRead
                                      ? Colors.black12
                                      : const Color(0xFFF2DFDA),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      isRead
                                          ? Colors.grey.shade100
                                          : const Color(0xFFFFF1ED),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _iconForType(type),
                                  color:
                                      isRead
                                          ? Colors.black54
                                          : const Color(0xFFB86E5D),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (data['title'] ?? 'Notification')
                                                .toString(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 9,
                                            height: 9,
                                            decoration: const BoxDecoration(
                                              color: kPrimary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      (data['message'] ?? '').toString(),
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _timeAgo(createdAt),
                                      style: const TextStyle(
                                        color: Colors.black45,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
