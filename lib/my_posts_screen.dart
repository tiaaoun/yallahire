import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_feedback.dart';
import 'post_requests_screen.dart';
import 'chat_screen.dart';
import 'notification_service.dart';
import 'post_screen.dart';
import 'widgets/post_card.dart';
import 'widgets/post_action_menu_button.dart';
import 'user_profile_screen.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen>
    with AutomaticKeepAliveClientMixin {
  static const Color kBg = Colors.white;
  static const Color kPrimary = Color(0xFFE89C8A);

  String selectedMainTab = 'posts';

  String fullName = 'User';
  String? imageUrl;
  bool profileLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => profileLoaded = true);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(user.uid)
              .get();

      final data = doc.data();
      if (!mounted) return;

      setState(() {
        fullName =
            (data?['fullName']?.toString().trim().isNotEmpty ?? false)
                ? data!['fullName'].toString()
                : 'User';
        imageUrl = data?['imageUrl']?.toString();
        profileLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => profileLoaded = true);
    }
  }

  Widget _toggleButton({
    required String label,
    required String value,
    required String selectedValue,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedValue == value;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? kPrimary : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? kPrimary : Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openRequestsScreen({
    required String postId,
    required String postTitle,
    required bool isJobPost,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PostRequestsScreen(
              postId: postId,
              postTitle: postTitle,
              isJobPost: isJobPost,
            ),
      ),
    );
  }

  void _openChat({required String peerId, required String peerName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(peerId: peerId, peerName: peerName),
      ),
    );
  }

  void _openUserProfile(String userId) {
    if (userId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    );
  }

  Future<void> _showMessageDialog(String message, {String title = 'Notice'}) {
    return showAppMessageDialog(context, title: title, message: message);
  }

  Future<bool> _showDeletePostDialog() async {
    if (!mounted) return false;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
            contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
            actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            title: const Text(
              'Delete post?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            content: const Text(
              'Are you sure you want to delete this post?',
              style: TextStyle(
                color: Colors.black87,
                height: 1.4,
                fontSize: 15,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black54,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );

    if (!mounted) return false;
    return shouldDelete ?? false;
  }

  Future<void> _editPost(String postId, Map<String, dynamic> postData) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => PostScreen(editingPostId: postId, initialPostData: postData),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      setState(() {});
    }
  }

  Widget _buildPostActionsMenu(String postId, Map<String, dynamic> postData) {
    return PostActionMenuButton(
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
          if (!mounted) return;
          if (value == 'edit') {
            _editPost(postId, postData);
            return;
          }
          if (value == 'delete') {
            _deletePost(postId);
          }
        });
      },
    );
  }

  Future<void> _deletePost(String postId) async {
    final shouldDelete = await _showDeletePostDialog();
    if (!mounted) return;
    if (!shouldDelete) return;

    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Delete failed',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              content: Text(
                '$e',
                style: const TextStyle(color: Colors.black87, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green.shade100;
      case 'rejected':
        return Colors.red.shade100;
      case 'completed':
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green.shade800;
      case 'rejected':
        return Colors.red.shade800;
      case 'completed':
        return Colors.black87;
      default:
        return Colors.grey.shade800;
    }
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _statusColor(status),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: _statusTextColor(status),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmCompletionDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Confirm completion?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              content: const Text(
                'Are you sure this task has been completed?',
                style: TextStyle(color: Colors.black87, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _confirmCompletionForMyRequest({
    required String postId,
    required String collectionName,
    required String docId,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    final shouldContinue = await _showConfirmCompletionDialog();
    if (!shouldContinue) return;

    final requestRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection(collectionName)
        .doc(docId);

    final requestDoc = await requestRef.get();
    final requestData = requestDoc.data() ?? {};

    // completion confirmation marks the interaction ready for the review stage.
    await requestRef.update({
      'interactionStatus': 'completed',
      'completionRequested': true,
      'completionRequestedBy': currentUserId,
      'completionRequestedAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
      'confirmedCompletedBy': currentUserId,
    });

    final postOwnerUid = (requestData['postOwnerUid'] ?? '').toString();
    final otherUid =
        collectionName == 'applications'
            ? (requestData['applicantUid'] ?? '').toString()
            : (requestData['hirerUid'] ?? '').toString();

    if (postOwnerUid.isNotEmpty) {
      // both sides receive a reminder so each user can leave a review after completion.
      await AppNotificationService.createNotification(
        userId: postOwnerUid,
        type: 'review_reminder',
        title: 'Review reminder',
        message: 'Your task was completed. Leave a review.',
        relatedPostId: postId,
      );
    }

    if (otherUid.isNotEmpty && otherUid != postOwnerUid) {
      await AppNotificationService.createNotification(
        userId: otherUid,
        type: 'review_reminder',
        title: 'Review reminder',
        message: 'Your task was completed. Leave a review.',
        relatedPostId: postId,
      );
    }
  }

  Future<void> _submitReview({
    required String postId,
    required String docId,
    required String collectionName,
    required String toUid,
    required int rating,
    required String comment,
    required List<String> tags,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final currentUserId = currentUser.uid;

    final requestRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection(collectionName)
        .doc(docId);

    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      throw Exception('Request not found.');
    }

    final data = requestDoc.data() ?? {};
    final postOwnerUid =
        (data['postOwnerUid'] ?? '').toString().isNotEmpty
            ? (data['postOwnerUid'] ?? '').toString()
            : ((await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(postId)
                            .get())
                        .data()?['postedBy'] ??
                    '')
                .toString();
    final isPoster = currentUserId == postOwnerUid;

    if (toUid.trim().isEmpty) {
      throw Exception('User not found.');
    }

    final currentProfileDoc =
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(currentUserId)
            .get();
    final currentProfile = currentProfileDoc.data() ?? {};
    final fromName = (currentProfile['fullName'] ?? 'User').toString();

    final reviewRef =
        FirebaseFirestore.instance
            .collection('profiles')
            .doc(toUid)
            .collection('reviews')
            .doc();

    // reviews are stored under the reviewed user's profile for public profile display.
    await reviewRef.set({
      'fromUid': currentUserId,
      'fromName': fromName,
      'toUid': toUid,
      'postId': postId,
      'requestId': docId,
      'collectionName': collectionName,
      'rating': rating,
      'comment': comment.trim(),
      'tags': tags,
      'role': isPoster ? 'poster_to_other' : 'other_to_poster',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await requestRef.update({
      // store which side has already reviewed to prevent duplicate submissions.
      isPoster ? 'reviewedByPoster' : 'reviewedByOtherUser': true,
    });
  }

  Future<void> _showReviewSheet({
    required String postId,
    required String docId,
    required String collectionName,
    required String toUid,
    required bool isPosterReviewing,
  }) async {
    int rating = 5;
    final commentController = TextEditingController();
    final selectedTags = <String>{};

    final tags =
        isPosterReviewing
            ? [
              'On time',
              'Professional',
              'Friendly',
              'Reliable',
              'Good communication',
              'Skilled',
            ]
            : [
              'Respectful',
              'Clear instructions',
              'Paid on time',
              'Responsive',
              'Honest',
              'Easy to work with',
            ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Center(
                      child: Text(
                        'Leave Review',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        return IconButton(
                          onPressed: () {
                            setSheetState(() {
                              rating = star;
                            });
                          },
                          icon: Icon(
                            Icons.star,
                            size: 32,
                            color:
                                star <= rating
                                    ? Colors.amber
                                    : Colors.grey.shade300,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tags',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          tags.map((tag) {
                            final isSelected = selectedTags.contains(tag);
                            return FilterChip(
                              label: Text(tag),
                              selected: isSelected,
                              onSelected: (selected) {
                                setSheetState(() {
                                  if (selected) {
                                    if (selectedTags.length < 3) {
                                      selectedTags.add(tag);
                                    }
                                  } else {
                                    selectedTags.remove(tag);
                                  }
                                });
                              },
                              selectedColor: const Color(0xFFF7D8D1),
                              checkmarkColor: const Color(0xFFB86E5D),
                              labelStyle: TextStyle(
                                color:
                                    isSelected
                                        ? const Color(0xFFB86E5D)
                                        : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              backgroundColor: Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      maxLines: 4,
                      cursorColor: kPrimary,
                      decoration: InputDecoration(
                        hintText: 'Write a short review...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.black26),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: kPrimary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await _submitReview(
                              postId: postId,
                              docId: docId,
                              collectionName: collectionName,
                              toUid: toUid,
                              rating: rating,
                              comment: commentController.text,
                              tags: selectedTags.toList(),
                            );

                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            if (!mounted) return;
                            setState(() {});
                          } catch (e) {
                            if (!mounted) return;
                            await _showMessageDialog(
                              'Error: $e',
                              title: 'Error',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Submit Review',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInteractionTopRight(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    final interactionStatus =
        (item['interactionStatus'] ?? '').toString().toLowerCase();

    if (interactionStatus == 'completed') {
      return _buildStatusChip('completed');
    }

    return _buildStatusChip(status);
  }

  Widget? _buildInteractionActions({
    required User user,
    required Map<String, dynamic> item,
  }) {
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    final interactionStatus =
        (item['interactionStatus'] ?? '').toString().toLowerCase();
    final posterUid = (item['posterUid'] ?? '').toString();
    final posterName = (item['posterName'] ?? 'User').toString();
    final docId = (item['docId'] ?? '').toString();
    final postId = (item['postId'] ?? '').toString();
    final collectionName = (item['collectionName'] ?? '').toString();
    final reviewedByOtherUser = item['reviewedByOtherUser'] == true;

    final isAccepted = status == 'accepted';
    final isInProgress = interactionStatus == 'in_progress';
    final isCompleted = interactionStatus == 'completed';

    if (isAccepted && isInProgress) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed:
                posterUid.isEmpty
                    ? null
                    : () => _openChat(peerId: posterUid, peerName: posterName),
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimary,
              side: const BorderSide(color: kPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: const Text('Chat'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _confirmCompletionForMyRequest(
                  postId: postId,
                  collectionName: collectionName,
                  docId: docId,
                );
                if (!mounted) return;
                setState(() {});
              } catch (e) {
                if (!mounted) return;
                await _showMessageDialog('Error: $e', title: 'Error');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: const Text('Confirm Completion'),
          ),
        ],
      );
    }

    if (isCompleted) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed:
                posterUid.isEmpty
                    ? null
                    : () => _openChat(peerId: posterUid, peerName: posterName),
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimary,
              side: const BorderSide(color: kPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: const Text('Chat'),
          ),
          ElevatedButton(
            onPressed:
                reviewedByOtherUser
                    ? null
                    : () => _showReviewSheet(
                      postId: postId,
                      docId: docId,
                      collectionName: collectionName,
                      toUid: posterUid,
                      isPosterReviewing: false,
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  reviewedByOtherUser ? Colors.grey.shade300 : kPrimary,
              foregroundColor:
                  reviewedByOtherUser ? Colors.black54 : Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.black54,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: Text(
              reviewedByOtherUser ? 'Review Submitted' : 'Leave Review',
            ),
          ),
        ],
      );
    }

    if (status == 'accepted') {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed:
                posterUid.isEmpty
                    ? null
                    : () => _openChat(peerId: posterUid, peerName: posterName),
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimary,
              side: const BorderSide(color: kPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: const Text('Chat'),
          ),
        ],
      );
    }

    return null;
  }

  Widget _buildMyPostsTab(User user) {
    return FutureBuilder<Map<String, List<QueryDocumentSnapshot>>>(
      future: _loadMyCreatedPosts(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final hiringPosts = snapshot.data?['job'] ?? [];
        final servicePosts = snapshot.data?['service'] ?? [];

        if (hiringPosts.isEmpty && servicePosts.isEmpty) {
          return const Center(
            child: Text('No posts yet.', style: TextStyle(fontSize: 16)),
          );
        }

        return ListView(
          key: const PageStorageKey('activity_my_posts_list'),
          children: [
            if (hiringPosts.isNotEmpty) ...[
              _buildSectionTitle(
                'Hiring Posts',
                'Posts where you are looking for someone',
              ),
              ...hiringPosts.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isOwner = (data['postedBy'] ?? '').toString() == user.uid;
                return PostCard(
                  posterName: fullName,
                  posterImageUrl: imageUrl ?? '',
                  createdAt: data['createdAt'] as Timestamp?,
                  title: (data['title'] ?? 'No Title').toString(),
                  description: (data['description'] ?? '').toString(),
                  city: (data['city'] ?? 'Unknown').toString(),
                  price: (data['price'] ?? 'N/A').toString(),
                  currency: (data['currency'] ?? '\$').toString(),
                  onProfileTap: () => _openUserProfile(user.uid),
                  topRight:
                      isOwner ? _buildPostActionsMenu(doc.id, data) : null,
                  trailing: OutlinedButton(
                    onPressed:
                        () => _openRequestsScreen(
                          postId: doc.id,
                          postTitle: (data['title'] ?? 'No Title').toString(),
                          isJobPost: true,
                        ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimary,
                      side: const BorderSide(color: kPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('View Applicants'),
                  ),
                );
              }),
            ],
            if (servicePosts.isNotEmpty) ...[
              _buildSectionTitle(
                'Service Posts',
                'Posts where you are offering work or services',
              ),
              ...servicePosts.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isOwner = (data['postedBy'] ?? '').toString() == user.uid;
                return PostCard(
                  posterName: fullName,
                  posterImageUrl: imageUrl ?? '',
                  createdAt: data['createdAt'] as Timestamp?,
                  title: (data['title'] ?? 'No Title').toString(),
                  description: (data['description'] ?? '').toString(),
                  city: (data['city'] ?? 'Unknown').toString(),
                  price: (data['price'] ?? 'N/A').toString(),
                  currency: (data['currency'] ?? '\$').toString(),
                  onProfileTap: () => _openUserProfile(user.uid),
                  topRight:
                      isOwner ? _buildPostActionsMenu(doc.id, data) : null,
                  trailing: OutlinedButton(
                    onPressed:
                        () => _openRequestsScreen(
                          postId: doc.id,
                          postTitle: (data['title'] ?? 'No Title').toString(),
                          isJobPost: false,
                        ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimary,
                      side: const BorderSide(color: kPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('View Hire Requests'),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMyRequestsTab(User user) {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _loadMyRequestsGrouped(user.uid),
      builder: (context, requestSnapshot) {
        if (requestSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimary),
          );
        }

        if (requestSnapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${requestSnapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final applications = requestSnapshot.data?['applications'] ?? [];
        final hireRequests = requestSnapshot.data?['hireRequests'] ?? [];

        if (applications.isEmpty && hireRequests.isEmpty) {
          return const Center(
            child: Text('No requests yet.', style: TextStyle(fontSize: 16)),
          );
        }

        return ListView(
          key: const PageStorageKey('activity_my_requests_list'),
          children: [
            if (applications.isNotEmpty) ...[
              _buildSectionTitle('Applications Sent', 'Jobs you applied to'),
              ...applications.map((item) {
                final posterUid = (item['posterUid'] ?? '').toString();
                return PostCard(
                  posterName: (item['posterName'] ?? 'User').toString(),
                  posterImageUrl: item['posterImageUrl'] as String? ?? '',
                  createdAt: item['time'] as Timestamp?,
                  title: item['title'] as String,
                  description: item['description'] as String,
                  city: item['city'] as String,
                  price: item['price'] as String,
                  currency: item['currency'] as String,
                  onProfileTap: () => _openUserProfile(posterUid),
                  topRight: _buildInteractionTopRight(item),
                  trailing: _buildInteractionActions(user: user, item: item),
                );
              }),
            ],
            if (hireRequests.isNotEmpty) ...[
              _buildSectionTitle(
                'Hire Requests Sent',
                'Services you requested',
              ),
              ...hireRequests.map((item) {
                final posterUid = (item['posterUid'] ?? '').toString();
                return PostCard(
                  posterName: (item['posterName'] ?? 'User').toString(),
                  posterImageUrl: item['posterImageUrl'] as String? ?? '',
                  createdAt: item['time'] as Timestamp?,
                  title: item['title'] as String,
                  description: item['description'] as String,
                  city: item['city'] as String,
                  price: item['price'] as String,
                  currency: item['currency'] as String,
                  onProfileTap: () => _openUserProfile(posterUid),
                  topRight: _buildInteractionTopRight(item),
                  trailing: _buildInteractionActions(user: user, item: item),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Future<Map<String, List<QueryDocumentSnapshot>>> _loadMyCreatedPosts(
    String currentUserUid,
  ) async {
    final postSnapshot =
        await FirebaseFirestore.instance
            .collection('posts')
            .where('postedBy', isEqualTo: currentUserUid)
            .get();

    final jobPosts = <QueryDocumentSnapshot>[];
    final servicePosts = <QueryDocumentSnapshot>[];

    for (final doc in postSnapshot.docs) {
      final data = doc.data();
      final type = (data['type'] ?? 'job').toString();

      if (type == 'job') {
        jobPosts.add(doc);
      } else {
        servicePosts.add(doc);
      }
    }

    jobPosts.sort((a, b) {
      final at = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final bt = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      return (bt?.millisecondsSinceEpoch ?? 0).compareTo(
        at?.millisecondsSinceEpoch ?? 0,
      );
    });

    servicePosts.sort((a, b) {
      final at = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final bt = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      return (bt?.millisecondsSinceEpoch ?? 0).compareTo(
        at?.millisecondsSinceEpoch ?? 0,
      );
    });

    return {'job': jobPosts, 'service': servicePosts};
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadMyRequestsGrouped(
    String currentUserUid,
  ) async {
    final List<Map<String, dynamic>> applications = [];
    final List<Map<String, dynamic>> hireRequests = [];

    final postSnapshot =
        await FirebaseFirestore.instance.collection('posts').get();

    // collect this user's requests by scanning posts and checking the matching subcollections.
    for (final postDoc in postSnapshot.docs) {
      final postData = postDoc.data();
      final postId = postDoc.id;

      final title = (postData['title'] ?? 'No Title').toString();
      final description = (postData['description'] ?? '').toString();
      final posterName = (postData['posterName'] ?? 'User').toString();
      final posterImageUrl = (postData['posterImageUrl'] ?? '').toString();
      final posterUid = (postData['postedBy'] ?? '').toString();
      final city = (postData['city'] ?? 'Unknown').toString();
      final price = (postData['price'] ?? 'N/A').toString();
      final currency = (postData['currency'] ?? '\$').toString();

      try {
        final applicationSnapshot =
            await FirebaseFirestore.instance
                .collection('posts')
                .doc(postId)
                .collection('applications')
                .where('applicantUid', isEqualTo: currentUserUid)
                .limit(1)
                .get();

        if (applicationSnapshot.docs.isNotEmpty) {
          final appDoc = applicationSnapshot.docs.first;
          final appData = appDoc.data();

          applications.add({
            'docId': appDoc.id,
            'postId': postId,
            'collectionName': 'applications',
            'title': title,
            'description': description,
            'posterName': posterName,
            'posterImageUrl': posterImageUrl,
            'posterUid': posterUid,
            'city': city,
            'price': price,
            'currency': currency,
            'status': (appData['status'] ?? 'pending').toString(),
            'interactionStatus':
                (appData['interactionStatus'] ?? '').toString(),
            'completionRequested': appData['completionRequested'] == true,
            'completionRequestedBy':
                (appData['completionRequestedBy'] ?? '').toString(),
            'reviewedByPoster': appData['reviewedByPoster'] == true,
            'reviewedByOtherUser': appData['reviewedByOtherUser'] == true,
            'time': appData['appliedAt'] as Timestamp?,
          });
        }
      } catch (e) {
        debugPrint('Applications read error for post $postId: $e');
      }

      try {
        final hireRequestSnapshot =
            await FirebaseFirestore.instance
                .collection('posts')
                .doc(postId)
                .collection('hireRequests')
                .where('hirerUid', isEqualTo: currentUserUid)
                .limit(1)
                .get();

        if (hireRequestSnapshot.docs.isNotEmpty) {
          final hireDoc = hireRequestSnapshot.docs.first;
          final hireData = hireDoc.data();

          hireRequests.add({
            'docId': hireDoc.id,
            'postId': postId,
            'collectionName': 'hireRequests',
            'title': title,
            'description': description,
            'posterName': posterName,
            'posterImageUrl': posterImageUrl,
            'posterUid': posterUid,
            'city': city,
            'price': price,
            'currency': currency,
            'status': (hireData['status'] ?? 'pending').toString(),
            'interactionStatus':
                (hireData['interactionStatus'] ?? '').toString(),
            'completionRequested': hireData['completionRequested'] == true,
            'completionRequestedBy':
                (hireData['completionRequestedBy'] ?? '').toString(),
            'reviewedByPoster': hireData['reviewedByPoster'] == true,
            'reviewedByOtherUser': hireData['reviewedByOtherUser'] == true,
            'time': hireData['createdAt'] as Timestamp?,
          });
        }
      } catch (e) {
        debugPrint('Hire requests read error for post $postId: $e');
      }
    }

    applications.sort((a, b) {
      final aTs = a['time'] as Timestamp?;
      final bTs = b['time'] as Timestamp?;
      return (bTs?.millisecondsSinceEpoch ?? 0).compareTo(
        aTs?.millisecondsSinceEpoch ?? 0,
      );
    });

    hireRequests.sort((a, b) {
      final aTs = a['time'] as Timestamp?;
      final bTs = b['time'] as Timestamp?;
      return (bTs?.millisecondsSinceEpoch ?? 0).compareTo(
        aTs?.millisecondsSinceEpoch ?? 0,
      );
    });

    return {'applications': applications, 'hireRequests': hireRequests};
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Activity', style: TextStyle(color: Colors.black)),
        backgroundColor: kBg,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body:
          user == null
              ? const Center(
                child: Text('Please log in to view your activity.'),
              )
              : !profileLoaded
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                    child: Row(
                      children: [
                        _toggleButton(
                          label: 'My Posts',
                          value: 'posts',
                          selectedValue: selectedMainTab,
                          onTap:
                              () => setState(() => selectedMainTab = 'posts'),
                        ),
                        const SizedBox(width: 12),
                        _toggleButton(
                          label: 'My Requests',
                          value: 'requests',
                          selectedValue: selectedMainTab,
                          onTap:
                              () =>
                                  setState(() => selectedMainTab = 'requests'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child:
                        selectedMainTab == 'posts'
                            ? _buildMyPostsTab(user)
                            : _buildMyRequestsTab(user),
                  ),
                ],
              ),
    );
  }
}
