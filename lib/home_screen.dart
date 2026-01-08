import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'notifications_screen.dart'; // NEW

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<bool> _hasApplied(String jobId, String userId) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .collection('applications')
            .doc(userId)
            .get();
    return doc.exists;
  }

  Future<void> _applyToJob(
    BuildContext context,
    String jobId,
    String jobTitle,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to apply.')),
      );
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('applications')
        .doc(user.uid);

    final alreadyApplied = await docRef.get();
    if (alreadyApplied.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already applied to this job.')),
      );
      return;
    }

    final application = {
      'userId': user.uid,
      'email': user.email,
      'appliedAt': Timestamp.now(),
    };

    try {
      await docRef.set(application);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ Applied for "$jobTitle"!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  Future<void> _openChat(BuildContext context, String peerId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final ids = [currentUser.uid, peerId]..sort();
    final chatId = '${ids[0]}_${ids[1]}';

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) {
      await chatRef.set({
        'participants': ids,
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    final peerDoc =
        await FirebaseFirestore.instance.collection('users').doc(peerId).get();
    final peerName = peerDoc.data()?['fullName'] ?? 'User';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(peerId: peerId, peerName: peerName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('YallaHire', style: TextStyle(color: Colors.black)),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('jobs')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final jobs = snapshot.data!.docs;
          if (jobs.isEmpty) {
            return const Center(
              child: Text('No tasks yet.', style: TextStyle(fontSize: 18)),
            );
          }

          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index].data() as Map<String, dynamic>;
              final jobId = jobs[index].id;

              final title = job['title'] ?? 'No Title';
              final desc = job['description'] ?? '';
              final category = job['category'] ?? 'Other';
              final city = job['city'] ?? 'Unknown';
              final price = job['price'] ?? 'N/A';
              final currency = job['currency'] ?? 'LBP';
              final postedBy = job['postedBy'] ?? '';

              final caregivingColor = const Color.fromARGB(255, 244, 228, 228);
              final chip = Chip(
                label: Text(category),
                backgroundColor:
                    category == 'Caregiving'
                        ? caregivingColor
                        : Colors.grey.shade200,
              );

              return FutureBuilder<bool>(
                future:
                    currentUser != null
                        ? _hasApplied(jobId, currentUser.uid)
                        : Future.value(false),
                builder: (context, appliedSnapshot) {
                  final hasApplied = appliedSnapshot.data ?? false;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    color: Colors.white,
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
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            desc,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              chip,
                              const SizedBox(width: 8),
                              Text('📍 $city'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '💰 $price $currency',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => _openChat(context, postedBy),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFE78D83),
                                  side: const BorderSide(
                                    color: Color(0xFFE78D83),
                                  ),
                                ),
                                child: const Text('Chat'),
                              ),
                              const SizedBox(width: 8),
                              hasApplied
                                  ? ElevatedButton(
                                    onPressed: null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade300,
                                      foregroundColor: Colors.grey.shade600,
                                    ),
                                    child: const Text('Applied'),
                                  )
                                  : ElevatedButton(
                                    onPressed:
                                        () =>
                                            _applyToJob(context, jobId, title),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE78D83),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Apply'),
                                  ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
