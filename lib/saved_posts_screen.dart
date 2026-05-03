import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_feedback.dart';
import 'chat_screen.dart';
import 'post_screen.dart';
import 'report_post_sheet.dart';
import 'widgets/post_action_menu_button.dart';

class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  static const Color kBg = Colors.white;
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

    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '$weeks week${weeks > 1 ? 's' : ''} ago';

    final months = (diff.inDays / 30).floor();
    if (months < 12) return '$months month${months > 1 ? 's' : ''} ago';

    final years = (diff.inDays / 365).floor();
    return '$years year${years > 1 ? 's' : ''} ago';
  }

  Widget _smallInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 4),
        Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }

  void _handleFeedback(BuildContext context, String text) {
    final lower = text.toLowerCase();
    final shouldShowDialog =
        lower.contains('error') ||
        lower.contains('failed') ||
        lower.contains('must') ||
        lower.contains("can't") ||
        lower.contains('missing') ||
        lower.contains('please');

    if (!shouldShowDialog) return;

    showAppMessageDialog(
      context,
      title:
          lower.contains('error') || lower.contains('failed')
              ? 'Error'
              : 'Notice',
      message: text,
    );
  }

  Future<bool> _showDeletePostDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'Delete post?',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'Are you sure you want to delete this post?',
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  Future<void> _deletePost(BuildContext context, String postId) async {
    final shouldDelete = await _showDeletePostDialog(context);
    if (!context.mounted || !shouldDelete) return;

    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      if (!context.mounted) return;
      _handleFeedback(context, 'Post deleted.');
    } catch (e) {
      if (!context.mounted) return;
      _handleFeedback(context, 'Delete failed: $e');
    }
  }

  Future<void> _editPost(
    BuildContext context,
    String postId,
    Map<String, dynamic> postData,
  ) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => PostScreen(editingPostId: postId, initialPostData: postData),
      ),
    );
  }

  Widget _buildHeaderActions(
    BuildContext context, {
    required String postId,
    required Map<String, dynamic> postData,
    required String postedBy,
    required String currentUserUid,
  }) {
    final isOwner = postedBy == currentUserUid;

    if (isOwner) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _removeSavedPost(context, postId),
            icon: const Icon(Icons.bookmark, color: kPrimary),
          ),
          PostActionMenuButton(
            items: const [
              PostActionMenuItemData(
                value: 'edit',
                label: 'Edit',
                icon: Icons.edit_outlined,
                color: Colors.black87,
              ),
              PostActionMenuItemData(
                value: 'delete',
                label: 'Delete',
                icon: Icons.delete_outline,
                color: Color(0xFFB86E5D),
              ),
            ],
            onSelected: (value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                if (value == 'edit') {
                  _editPost(context, postId, postData);
                } else if (value == 'delete') {
                  _deletePost(context, postId);
                }
              });
            },
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _removeSavedPost(context, postId),
          icon: const Icon(Icons.bookmark, color: kPrimary),
        ),
        PostActionMenuButton(
          items: const [
            PostActionMenuItemData(
              value: 'report',
              label: 'Report',
              icon: Icons.flag_outlined,
              color: Color(0xFFB86E5D),
            ),
          ],
          onSelected: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              showReportPostSheet(
                context,
                postId: postId,
                postTitle: (postData['title'] ?? 'Post').toString(),
                postOwnerUid: postedBy,
                postOwnerName:
                    (postData['posterName'] ?? postData['postedBy'] ?? 'User')
                        .toString(),
              );
            });
          },
        ),
      ],
    );
  }

  Future<void> _removeSavedPost(BuildContext context, String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(user.uid)
          .collection('saved')
          .doc(postId)
          .delete();

      if (!context.mounted) return;
      _handleFeedback(context, 'Removed from saved posts.');
    } catch (e) {
      if (!context.mounted) return;
      _handleFeedback(context, 'Error: $e');
    }
  }

  Future<bool> _hasApplied(String postId, String userId) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .collection('applications')
            .doc(userId)
            .get();
    return doc.exists;
  }

  Future<bool> _hasHireRequested(String postId, String userId) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .collection('hireRequests')
            .doc(userId)
            .get();
    return doc.exists;
  }

  Future<void> _applyToJob(
    BuildContext context,
    String postId,
    String postTitle,
    String postOwnerUid,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _handleFeedback(context, 'You must be logged in to apply.');
      return;
    }

    if (postOwnerUid.isEmpty || postOwnerUid == user.uid) {
      _handleFeedback(context, "You can't apply to your own post.");
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('applications')
        .doc(user.uid);

    try {
      final profileDoc =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(user.uid)
              .get();

      final profile = profileDoc.data() ?? {};

      final application = {
        'applicantUid': user.uid,
        'postOwnerUid': postOwnerUid,
        'applicantEmail': user.email,
        'applicantName': (profile['fullName'] ?? 'User').toString(),
        'applicantImageUrl': (profile['imageUrl'] ?? '').toString(),
        'applicantBirthYear': (profile['birthYear'] ?? '').toString(),
        'applicantGender': (profile['gender'] ?? '').toString(),
        'applicantOccupation': (profile['occupation'] ?? '').toString(),
        'applicantCity': (profile['city'] ?? '').toString(),
        'applicantPhone': (profile['phoneNumber'] ?? '').toString(),
        'appliedAt': Timestamp.now(),
        'status': 'pending',
        'message': '',
      };

      await docRef.set(application);

      if (!context.mounted) return;
      _handleFeedback(context, 'Applied for "$postTitle".');
    } catch (e) {
      if (!context.mounted) return;
      _handleFeedback(context, 'Error: $e');
    }
  }

  Future<void> _hireService(
    BuildContext context,
    String postId,
    String postTitle,
    String postOwnerUid,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _handleFeedback(context, 'You must be logged in to hire.');
      return;
    }

    if (postOwnerUid.isEmpty || postOwnerUid == user.uid) {
      _handleFeedback(context, "You can't hire yourself.");
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('hireRequests')
        .doc(user.uid);

    try {
      final profileDoc =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(user.uid)
              .get();

      final profile = profileDoc.data() ?? {};

      final requestData = {
        'hirerUid': user.uid,
        'postOwnerUid': postOwnerUid,
        'hirerEmail': user.email,
        'hirerName': (profile['fullName'] ?? 'User').toString(),
        'hirerImageUrl': (profile['imageUrl'] ?? '').toString(),
        'hirerBirthYear': (profile['birthYear'] ?? '').toString(),
        'hirerGender': (profile['gender'] ?? '').toString(),
        'hirerOccupation': (profile['occupation'] ?? '').toString(),
        'hirerCity': (profile['city'] ?? '').toString(),
        'hirerPhone': (profile['phoneNumber'] ?? '').toString(),
        'createdAt': Timestamp.now(),
        'status': 'pending',
        'message': '',
      };

      await docRef.set(requestData);

      if (!context.mounted) return;
      await _openChat(context, postOwnerUid);
    } catch (e) {
      if (!context.mounted) return;
      _handleFeedback(context, 'Error: $e');
    }
  }

  Future<void> _openChat(BuildContext context, String peerId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _handleFeedback(context, 'You must be logged in to chat.');
      return;
    }

    if (peerId.isEmpty) {
      _handleFeedback(context, 'Missing post owner.');
      return;
    }

    if (peerId == currentUser.uid) {
      _handleFeedback(context, "You can't chat with yourself.");
      return;
    }

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

    String peerName = 'User';

    final profileDoc =
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(peerId)
            .get();

    if (profileDoc.exists) {
      final profileData = profileDoc.data();
      peerName =
          (profileData?['fullName']?.toString().trim().isNotEmpty ?? false)
              ? profileData!['fullName'].toString()
              : 'User';
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(peerId: peerId, peerName: peerName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Saved Posts', style: TextStyle(color: Colors.black)),
      ),
      body:
          user == null
              ? const Center(child: Text('Please log in to view saved posts.'))
              : StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('profiles')
                        .doc(user.uid)
                        .collection('saved')
                        .orderBy('savedAt', descending: true)
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

                  final posts = snapshot.data?.docs ?? [];

                  if (posts.isEmpty) {
                    return const Center(
                      child: Text(
                        'No saved posts yet.',
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final doc = posts[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final postId = (data['postId'] ?? doc.id).toString();
                      final title = (data['title'] ?? 'No Title').toString();
                      final description =
                          (data['description'] ?? '').toString();
                      final city = (data['city'] ?? 'Unknown').toString();
                      final price = (data['price'] ?? 'N/A').toString();
                      final currency = (data['currency'] ?? '\$').toString();
                      final posterName =
                          (data['posterName'] ?? 'User').toString();
                      final posterImageUrl =
                          (data['posterImageUrl'] ?? '').toString();
                      final postedBy = (data['postedBy'] ?? '').toString();
                      final createdAt = data['createdAt'] as Timestamp?;
                      final type = (data['type'] ?? 'job').toString();

                      final isHiringPost = type == 'job';

                      return FutureBuilder<bool>(
                        future:
                            isHiringPost
                                ? _hasApplied(postId, user.uid)
                                : _hasHireRequested(postId, user.uid),
                        builder: (context, actionSnapshot) {
                          final alreadyDone = actionSnapshot.data ?? false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage:
                                            posterImageUrl.isNotEmpty
                                                ? NetworkImage(posterImageUrl)
                                                : null,
                                        child:
                                            posterImageUrl.isEmpty
                                                ? Icon(
                                                  Icons.person,
                                                  color: Colors.grey.shade500,
                                                  size: 20,
                                                )
                                                : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              posterName.isNotEmpty
                                                  ? posterName
                                                  : 'User',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _timeAgo(createdAt),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black45,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildHeaderActions(
                                        context,
                                        postId: postId,
                                        postData: data,
                                        postedBy: postedBy,
                                        currentUserUid: user.uid,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    description,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _smallInfo(
                                        Icons.location_on_outlined,
                                        city,
                                      ),
                                      const SizedBox(width: 18),
                                      _smallInfo(
                                        Icons.payments_outlined,
                                        '$price $currency',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed:
                                            () => _openChat(context, postedBy),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: kPrimary,
                                          side: const BorderSide(
                                            color: kPrimary,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              22,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 26,
                                            vertical: 12,
                                          ),
                                        ),
                                        child: const Text('Chat'),
                                      ),
                                      const SizedBox(width: 10),
                                      if (isHiringPost) ...[
                                        alreadyDone
                                            ? ElevatedButton(
                                              onPressed: null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.grey.shade300,
                                                foregroundColor:
                                                    Colors.grey.shade600,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 26,
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: const Text('Applied'),
                                            )
                                            : ElevatedButton(
                                              onPressed:
                                                  () => _applyToJob(
                                                    context,
                                                    postId,
                                                    title,
                                                    postedBy,
                                                  ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: kPrimary,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 26,
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: const Text('Apply'),
                                            ),
                                      ] else ...[
                                        alreadyDone
                                            ? ElevatedButton(
                                              onPressed:
                                                  () => _openChat(
                                                    context,
                                                    postedBy,
                                                  ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.grey.shade300,
                                                foregroundColor: Colors.black87,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 26,
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: const Text('Requested'),
                                            )
                                            : ElevatedButton(
                                              onPressed:
                                                  () => _hireService(
                                                    context,
                                                    postId,
                                                    title,
                                                    postedBy,
                                                  ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: kPrimary,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 26,
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: const Text('Hire'),
                                            ),
                                      ],
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
