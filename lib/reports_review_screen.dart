import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_feedback.dart';

class ReportsReviewScreen extends StatefulWidget {
  const ReportsReviewScreen({super.key});

  @override
  State<ReportsReviewScreen> createState() => _ReportsReviewScreenState();
}

class _ReportsReviewScreenState extends State<ReportsReviewScreen> {
  static const Color kPrimary = Color(0xFFE89C8A);

  Future<bool> _isCurrentUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // gate the screen using the admin flag stored on the user's profile document.
    final profile =
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(user.uid)
            .get();

    return profile.data()?['isAdmin'] == true;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _markReviewed(String reportId) async {
    // allow admins to close a report without deleting the related post.
    await FirebaseFirestore.instance.collection('reports').doc(reportId).update(
      {'status': 'reviewed', 'reviewedAt': FieldValue.serverTimestamp()},
    );
  }

  Future<bool> _confirmDeletePost() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Delete reported post?',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'This will remove the post from YallaHire.',
              style: TextStyle(color: Colors.black87, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF1ED),
                  foregroundColor: const Color(0xFFB86E5D),
                  elevation: 0,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  Future<void> _deleteReportedPost({
    required String reportId,
    required String postId,
  }) async {
    final shouldDelete = await _confirmDeletePost();
    if (!mounted || !shouldDelete) return;

    try {
      // moderation removes the post, then records the final review outcome on the report.
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
            'status': 'post_deleted',
            'reviewedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (!mounted) return;
      await showAppMessageDialog(context, title: 'Error', message: 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Reports Review',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<bool>(
        future: _isCurrentUserAdmin(),
        builder: (context, adminSnapshot) {
          if (adminSnapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimary),
            );
          }

          if (adminSnapshot.data != true) {
            return const Center(
              child: Text('Admins only.', style: TextStyle(fontSize: 16)),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('reports')
                    .where('status', isEqualTo: 'pending')
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

              final reports = snapshot.data?.docs ?? [];

              if (reports.isEmpty) {
                return const Center(
                  child: Text(
                    'No pending reports.',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final doc = reports[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt = data['createdAt'] as Timestamp?;
                  final details = (data['details'] ?? '').toString().trim();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4F1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            (data['reason'] ?? 'Report').toString(),
                            style: const TextStyle(
                              color: Color(0xFFB86E5D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (data['postTitle'] ?? 'Untitled post').toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Post owner: ${(data['postOwnerName'] ?? data['postOwnerUid'] ?? '').toString()}',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reported by: ${(data['reportedByName'] ?? data['reportedByUid'] ?? '').toString()}',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${_formatDate(createdAt)}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Text(
                              details,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _markReviewed(doc.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kPrimary,
                                side: const BorderSide(color: kPrimary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Mark reviewed'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    () => _deleteReportedPost(
                                      reportId: doc.id,
                                      postId: (data['postId'] ?? '').toString(),
                                    ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete post'),
                              ),
                            ),
                          ],
                        ),
                      ],
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
