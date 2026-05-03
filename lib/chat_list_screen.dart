import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  static const Color kPrimary = Color(0xFFE78D83);

  String _timeAgo(Timestamp? createdAt) {
    if (createdAt == null) return '';
    final now = DateTime.now();
    final date = createdAt.toDate();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '$weeks week${weeks > 1 ? 's' : ''} ago';

    final months = (diff.inDays / 30).floor();
    if (months < 12) return '$months month${months > 1 ? 's' : ''} ago';

    final years = (diff.inDays / 365).floor();
    return '$years year${years > 1 ? 's' : ''} ago';
  }

  String _previewText(String lastMessage) {
    if (lastMessage.trim().isEmpty) return 'Start chatting';

    if (lastMessage.startsWith('Great news — your application')) {
      return 'Application accepted';
    }

    if (lastMessage.startsWith('Great news — your hire request')) {
      return 'Hire request accepted';
    }

    return lastMessage;
  }

  Future<Map<String, String>> _loadAndRepairPeerInfo({
    required String chatId,
    required String peerId,
  }) async {
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(peerId)
          .get();

      final data = profileDoc.data() ?? {};
      final peerName = (data['fullName'] ?? '').toString().trim();
      final peerImageUrl = (data['imageUrl'] ?? '').toString().trim();

      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participantNames': {
          peerId: peerName,
        },
        'participantImages': {
          peerId: peerImageUrl,
        },
      }, SetOptions(merge: true));

      return {
        'name': peerName,
        'imageUrl': peerImageUrl,
      };
    } catch (_) {
      return {
        'name': '',
        'imageUrl': '',
      };
    }
  }

  Widget _buildUnreadBadge(int unreadCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        unreadCount > 99 ? '99+' : '$unreadCount',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildChatTile({
    required BuildContext context,
    required String chatId,
    required String peerId,
    required String peerName,
    required String peerImageUrl,
    required String lastMessage,
    required Timestamp? lastUpdated,
    required String currentUserId,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('seen', isEqualTo: false)
          .snapshots(),
      builder: (context, unreadSnapshot) {
        final unreadCount = unreadSnapshot.data?.docs.length ?? 0;
        final hasUnread = unreadCount > 0;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            backgroundImage:
                peerImageUrl.isNotEmpty ? NetworkImage(peerImageUrl) : null,
            child: peerImageUrl.isEmpty
                ? Icon(
                    Icons.person,
                    color: Colors.grey.shade500,
                  )
                : null,
          ),
          title: Text(
            peerName.isEmpty ? ' ' : peerName,
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
          subtitle: Text(
            _previewText(lastMessage),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasUnread ? Colors.black87 : Colors.black54,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _timeAgo(lastUpdated),
                style: TextStyle(
                  fontSize: 12,
                  color: hasUnread ? kPrimary : Colors.black45,
                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 6),
              if (hasUnread) _buildUnreadBadge(unreadCount),
            ],
          ),
          onTap: peerName.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        peerId: peerId,
                        peerName: peerName,
                      ),
                    ),
                  );
                },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text('Please log in to view your chats.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Chats',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
            .orderBy('lastUpdated', descending: true)
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

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimary),
            );
          }

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return const Center(
              child: Text(
                'No chats yet.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chatDoc = chats[index];
              final data = chatDoc.data() as Map<String, dynamic>;
              final chatId = chatDoc.id;

              final participants = List<String>.from(data['participants'] ?? []);
              final peerId = participants.firstWhere(
                (id) => id != currentUser.uid,
                orElse: () => '',
              );

              if (peerId.isEmpty) {
                return const SizedBox.shrink();
              }

              final participantNames =
                  Map<String, dynamic>.from(data['participantNames'] ?? {});
              final participantImages =
                  Map<String, dynamic>.from(data['participantImages'] ?? {});

              final directPeerName =
                  (participantNames[peerId] ?? '').toString().trim();
              final directPeerImage =
                  (participantImages[peerId] ?? '').toString().trim();

              final lastMessage = (data['lastMessage'] ?? '').toString();
              final lastUpdated = data['lastUpdated'] as Timestamp?;

              if (directPeerName.isNotEmpty) {
                return _buildChatTile(
                  context: context,
                  chatId: chatId,
                  peerId: peerId,
                  peerName: directPeerName,
                  peerImageUrl: directPeerImage,
                  lastMessage: lastMessage,
                  lastUpdated: lastUpdated,
                  currentUserId: currentUser.uid,
                );
              }

              return FutureBuilder<Map<String, String>>(
                future: _loadAndRepairPeerInfo(
                  chatId: chatId,
                  peerId: peerId,
                ),
                builder: (context, peerSnapshot) {
                  final repairedName =
                      (peerSnapshot.data?['name'] ?? '').toString().trim();
                  final repairedImage =
                      (peerSnapshot.data?['imageUrl'] ?? '').toString().trim();

                  return _buildChatTile(
                    context: context,
                    chatId: chatId,
                    peerId: peerId,
                    peerName: repairedName,
                    peerImageUrl: repairedImage,
                    lastMessage: lastMessage,
                    lastUpdated: lastUpdated,
                    currentUserId: currentUser.uid,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}