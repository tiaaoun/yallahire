import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final currentUserId = currentUser.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No chats yet.', style: TextStyle(fontSize: 16)),
            );
          }

          final chats =
              snapshot.data!.docs.where((doc) {
                final ids = doc.id.split('_');
                return ids.contains(currentUserId);
              }).toList();

          if (chats.isEmpty) {
            return const Center(
              child: Text('No chats yet.', style: TextStyle(fontSize: 16)),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chatDoc = chats[index];
              final data = chatDoc.data() as Map<String, dynamic>;
              final ids = chatDoc.id.split('_');
              final peerId = ids.firstWhere(
                (id) => id != currentUserId,
                orElse: () => currentUserId,
              );

              final lastMessage = data['lastMessage'] ?? '';
              final lastUpdated = data['lastUpdated'] as Timestamp?;

              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('profiles')
                        .doc(peerId)
                        .get(),
                builder: (context, userSnapshot) {
                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>?;

                  final peerName = userData?['fullName'] ?? 'User';
                  final imageUrl = userData?['imageUrl'];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFE78D83),
                      backgroundImage:
                          imageUrl != null ? NetworkImage(imageUrl) : null,
                      child:
                          imageUrl == null
                              ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 28,
                              )
                              : null,
                    ),
                    title: Text(
                      peerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    subtitle: Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    trailing:
                        lastUpdated != null
                            ? Text(
                              _formatTimestamp(lastUpdated),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            )
                            : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ChatScreen(
                                peerId: peerId,
                                peerName: peerName,
                              ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }
}
