import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_feedback.dart';
import 'chat_screen.dart';
import 'notifications_screen.dart';
import 'notification_service.dart';
import 'saved_posts_screen.dart';
import 'dashboard_screen.dart';
import 'my_posts_screen.dart';
import 'post_screen.dart';
import 'report_post_sheet.dart';
import 'user_profile_screen.dart';
import 'widgets/post_action_menu_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color kBg = Colors.white;
  static const Color kPrimary = Color(0xFFE89C8A);
  static const double _bestMatchThreshold = 0.35;

  String selectedType = 'job';

  final Map<String, bool> _appliedStatus = {};
  final Map<String, bool> _requestedStatus = {};
  final Map<String, bool> _savedStatus = {};
  final Map<String, Map<String, dynamic>> _profileCache = {};

  String _preparedPostsKey = '';

  void _handleFeedback(String text) {
    if (!mounted) return;

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

  Widget _buildNotificationsAction(User? currentUser) {
    if (currentUser == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_none, color: Colors.black),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: currentUser.uid)
              .where('isRead', isEqualTo: false)
              .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;

        return IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          icon: SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(
                  child: Icon(Icons.notifications_none, color: Colors.black),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showDeletePostDialog() async {
    if (!mounted) return false;

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

    if (!mounted) return false;
    return result ?? false;
  }

  Future<void> _deletePost(String postId) async {
    final shouldDelete = await _showDeletePostDialog();
    if (!mounted || !shouldDelete) return;

    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      if (!mounted) return;
      _handleFeedback('Post deleted.');
    } catch (e) {
      if (!mounted) return;
      _handleFeedback('Delete failed: $e');
    }
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

  Widget? _buildPostHeaderActions({
    required User? currentUser,
    required String postId,
    required Map<String, dynamic> postData,
    required bool isSaved,
  }) {
    if (currentUser == null) {
      return IconButton(
        onPressed: null,
        icon: const Icon(Icons.bookmark_border, color: Colors.black26),
      );
    }

    final postedBy = (postData['postedBy'] ?? '').toString();
    final isOwner = postedBy == currentUser.uid;

    if (isOwner) {
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
            } else if (value == 'delete') {
              _deletePost(postId);
            }
          });
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _toggleSavePost(postId, postData),
          icon: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            color: isSaved ? kPrimary : Colors.black54,
          ),
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
              if (!mounted) return;
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

  Future<bool> _hasCompleteProfile() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;

    // applying, hiring, and similar actions require a sufficiently completed user profile.
    final doc =
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(u.uid)
            .get();

    final profile = doc.data() ?? {};

    final requiredFields = [
      'fullName',
      'birthYear',
      'gender',
      'city',
      'occupation',
    ];

    for (final field in requiredFields) {
      final value = (profile[field] ?? '').toString().trim();
      if (value.isEmpty) return false;
    }

    final phone =
        (profile['phoneNumber'] ?? u.phoneNumber ?? '').toString().trim();
    final verified = profile['phoneVerified'] == true;

    return phone.isNotEmpty && verified;
  }

  Future<bool> _ensureCompleteProfile({required String action}) async {
    final ok = await _hasCompleteProfile();

    if (ok) return true;
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF4F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: kPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Complete your profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You need to complete your profile before you can $action.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black54,
                            side: const BorderSide(color: Colors.black12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Not now',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Complete',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (result == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(initialIndex: 4),
        ),
      );
    }

    return false;
  }

  Widget _typeToggleButton({required String label, required String value}) {
    final isSelected = selectedType == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedType = value;
            _preparedPostsKey = '';
          });
        },
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

  Future<bool> _isPostSaved(String postId, String userId) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(userId)
            .collection('saved')
            .doc(postId)
            .get();
    return doc.exists;
  }

  Future<void> _prepareVisiblePostStates({
    required List<QueryDocumentSnapshot> posts,
    required String userId,
    required bool isHiringPost,
  }) async {
    final key = '${selectedType}_${userId}_${posts.map((e) => e.id).join(",")}';

    // cache visible interaction states to avoid repeating Firestore reads during rebuilds.
    if (_preparedPostsKey == key) return;

    for (final post in posts) {
      final postId = post.id;

      if (isHiringPost) {
        _appliedStatus[postId] = await _hasApplied(postId, userId);
      } else {
        _requestedStatus[postId] = await _hasHireRequested(postId, userId);
      }

      _savedStatus[postId] = await _isPostSaved(postId, userId);
    }

    _preparedPostsKey = key;
  }

  Future<void> _toggleSavePost(
    String postId,
    Map<String, dynamic> postData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _handleFeedback('You must be logged in to save posts.');
      return;
    }

    final savedRef = FirebaseFirestore.instance
        .collection('profiles')
        .doc(user.uid)
        .collection('saved')
        .doc(postId);

    try {
      final existing = await savedRef.get();

      if (existing.exists) {
        // remove the saved reference when the user unbookmarks the post.
        await savedRef.delete();
        _savedStatus[postId] = false;
      } else {
        // store a lightweight snapshot so saved posts can be listed quickly later.
        await savedRef.set({
          'postId': postId,
          'savedAt': Timestamp.now(),
          'type': postData['type'],
          'title': postData['title'],
          'description': postData['description'],
          'city': postData['city'],
          'price': postData['price'],
          'currency': postData['currency'],
          'postedBy': postData['postedBy'],
          'posterName': postData['posterName'] ?? '',
          'posterImageUrl': postData['posterImageUrl'] ?? '',
          'createdAt': postData['createdAt'],
        });
        _savedStatus[postId] = true;
      }

      if (mounted) setState(() {});
    } catch (e) {
      _handleFeedback('Error: $e');
    }
  }

  Future<Map<String, dynamic>> _getCurrentUserProfile(User user) async {
    final profileDoc =
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(user.uid)
            .get();

    return profileDoc.data() ?? {};
  }

  Set<String> _extractKeywords(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.trim().length >= 3)
        .toSet();
  }

  bool _hasKeywordMatch(Set<String> source, String target) {
    if (source.isEmpty) return false;
    final targetKeywords = _extractKeywords(target);
    return source.any(targetKeywords.contains);
  }

  bool _hasCategoryMatch(Set<String> profileKeywords, String category) {
    if (category.trim().isEmpty || profileKeywords.isEmpty) return false;

    final categoryLower = category.toLowerCase().trim();
    if (profileKeywords.contains(categoryLower)) return true;

    return _hasKeywordMatch(profileKeywords, categoryLower);
  }

  double _calculateMatchScore(
    Map<String, dynamic> profile,
    Map<String, dynamic> post,
  ) {
    final userCity = (profile['city'] ?? '').toString().trim().toLowerCase();
    final occupation = (profile['occupation'] ?? '').toString().trim();
    final bio = (profile['bio'] ?? '').toString().trim();

    final postCity = (post['city'] ?? '').toString().trim().toLowerCase();
    final postCategory = (post['category'] ?? '').toString().trim();
    final postTitle = (post['title'] ?? '').toString().trim();
    final postDescription = (post['description'] ?? '').toString().trim();

    final profileKeywords = {
      ..._extractKeywords(occupation),
      ..._extractKeywords(bio),
    };

    double score = 0;

    // rank posts by simple profile-to-post relevance before falling back to recency.
    if (userCity.isNotEmpty && userCity == postCity) {
      score += 0.4;
    }

    if (_hasCategoryMatch(profileKeywords, postCategory)) {
      score += 0.3;
    }

    if (_hasKeywordMatch(profileKeywords, postTitle)) {
      score += 0.2;
    }

    if (_hasKeywordMatch(profileKeywords, postDescription)) {
      score += 0.1;
    }

    return score.clamp(0, 1).toDouble();
  }

  Future<void> _submitApplication({
    required String postId,
    required String postTitle,
    required String postOwnerUid,
    required String message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _handleFeedback('You must be logged in to apply.');
      return;
    }

    if (postOwnerUid.isEmpty || postOwnerUid == user.uid) {
      _handleFeedback("You can't apply to your own post.");
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('applications')
        .doc(user.uid);

    try {
      final profile = await _getCurrentUserProfile(user);

      // save one application per user under the post using the applicant UID as the document ID.
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
        'message': message.trim(),
      };

      await docRef.set(application);

      // notify the post owner that a new applicant has submitted details.
      await AppNotificationService.createNotification(
        userId: postOwnerUid,
        type: 'application_received',
        title: 'New application',
        message: 'Someone applied to your task: $postTitle',
        relatedPostId: postId,
      );

      _appliedStatus[postId] = true;
      if (mounted) setState(() {});
    } catch (e) {
      _handleFeedback('Error: $e');
    }
  }

  Future<void> _showApplySheet(
    String postId,
    String postTitle,
    String postOwnerUid,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _handleFeedback('You must be logged in to apply.');
      return;
    }

    if (postOwnerUid.isEmpty || postOwnerUid == user.uid) {
      _handleFeedback("You can't apply to your own post.");
      return;
    }

    try {
      final profile = await _getCurrentUserProfile(user);
      final messageController = TextEditingController();
      bool isSubmitting = false;

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          Widget infoRow(String label, String value) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 95,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value.isEmpty ? '-' : value,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

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
                      Text(
                        'Apply for $postTitle',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your profile details below will be shared with the poster.',
                        style: TextStyle(color: Colors.black54, height: 1.35),
                      ),
                      const SizedBox(height: 18),
                      infoRow('Name', (profile['fullName'] ?? '').toString()),
                      infoRow(
                        'Birth Year',
                        (profile['birthYear'] ?? '').toString(),
                      ),
                      infoRow('Gender', (profile['gender'] ?? '').toString()),
                      infoRow(
                        'Occupation',
                        (profile['occupation'] ?? '').toString(),
                      ),
                      infoRow('City', (profile['city'] ?? '').toString()),
                      infoRow(
                        'Phone',
                        (profile['phoneNumber'] ?? '').toString(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: messageController,
                        maxLines: 4,
                        cursorColor: kPrimary,
                        decoration: InputDecoration(
                          labelText: 'Message (optional)',
                          labelStyle: const TextStyle(color: Colors.black54),
                          floatingLabelStyle: const TextStyle(color: kPrimary),
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
                          onPressed:
                              isSubmitting
                                  ? null
                                  : () async {
                                    setSheetState(() => isSubmitting = true);

                                    await _submitApplication(
                                      postId: postId,
                                      postTitle: postTitle,
                                      postOwnerUid: postOwnerUid,
                                      message: messageController.text,
                                    );

                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          child:
                              isSubmitting
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text(
                                    'Send Application',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
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
    } catch (e) {
      _handleFeedback('Error: $e');
    }
  }

  Future<void> _submitHireRequest({
    required String postId,
    required String postTitle,
    required String postOwnerUid,
    required String message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _handleFeedback('You must be logged in to hire.');
      return;
    }

    if (postOwnerUid.isEmpty || postOwnerUid == user.uid) {
      _handleFeedback("You can't hire yourself.");
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('hireRequests')
        .doc(user.uid);

    try {
      final profile = await _getCurrentUserProfile(user);

      // service requests mirror applications, but target posts where someone is offering work.
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
        'message': message.trim(),
      };

      await docRef.set(requestData);

      await AppNotificationService.createNotification(
        userId: postOwnerUid,
        type: 'service_requested',
        title: 'New service request',
        message: 'Someone requested your service: $postTitle',
        relatedPostId: postId,
      );

      _requestedStatus[postId] = true;
      if (mounted) setState(() {});
    } catch (e) {
      _handleFeedback('Error: $e');
    }
  }

  Future<void> _showHireSheet(
    String postId,
    String postTitle,
    String postOwnerUid,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _handleFeedback('You must be logged in to hire.');
      return;
    }

    if (postOwnerUid.isEmpty || postOwnerUid == user.uid) {
      _handleFeedback("You can't hire yourself.");
      return;
    }

    try {
      final profile = await _getCurrentUserProfile(user);
      final messageController = TextEditingController();
      bool isSubmitting = false;

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          Widget infoRow(String label, String value) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 95,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value.isEmpty ? '-' : value,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

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
                      Text(
                        'Request $postTitle',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Share what you need before sending your request.',
                        style: TextStyle(color: Colors.black54, height: 1.35),
                      ),
                      const SizedBox(height: 18),
                      infoRow('Name', (profile['fullName'] ?? '').toString()),
                      infoRow('City', (profile['city'] ?? '').toString()),
                      infoRow(
                        'Phone',
                        (profile['phoneNumber'] ?? '').toString(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: messageController,
                        maxLines: 4,
                        cursorColor: kPrimary,
                        decoration: InputDecoration(
                          labelText: 'What do you need?',
                          hintText: 'Pickup point, time, details...',
                          labelStyle: const TextStyle(color: Colors.black54),
                          floatingLabelStyle: const TextStyle(color: kPrimary),
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
                          onPressed:
                              isSubmitting
                                  ? null
                                  : () async {
                                    setSheetState(() => isSubmitting = true);

                                    await _submitHireRequest(
                                      postId: postId,
                                      postTitle: postTitle,
                                      postOwnerUid: postOwnerUid,
                                      message: messageController.text,
                                    );

                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }

                                    if (!mounted) return;

                                    _handleFeedback('Request sent.');

                                    Navigator.push(
                                      this.context,
                                      MaterialPageRoute(
                                        builder: (_) => const MyPostsScreen(),
                                      ),
                                    );
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          child:
                              isSubmitting
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text(
                                    'Send Request',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
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
    } catch (e) {
      _handleFeedback('Error: $e');
    }
  }

  Future<void> _openChat(String peerId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _handleFeedback('You must be logged in to chat.');
      return;
    }

    if (peerId.isEmpty) {
      _handleFeedback('Missing post owner.');
      return;
    }

    if (peerId == currentUser.uid) {
      _handleFeedback("You can't chat with yourself.");
      return;
    }

    try {
      final ids = [currentUser.uid, peerId]..sort();
      // sort the participant IDs so both users always resolve the same chat document ID.
      final chatId = '${ids[0]}_${ids[1]}';

      final currentProfileDoc =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(currentUser.uid)
              .get();
      final peerProfileDoc =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(peerId)
              .get();

      final currentProfile = currentProfileDoc.data() ?? {};
      final peerProfile = peerProfileDoc.data() ?? {};

      final currentUserName =
          (currentProfile['fullName'] ?? '').toString().trim();
      final currentUserImage =
          (currentProfile['imageUrl'] ?? '').toString().trim();

      final peerName = (peerProfile['fullName'] ?? '').toString().trim();
      final peerImage = (peerProfile['imageUrl'] ?? '').toString().trim();

      _profileCache[currentUser.uid] = currentProfile;
      _profileCache[peerId] = peerProfile;

      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId);

      // merge profile metadata into the chat document so chat lists can render names and images.
      await chatRef.set({
        'participants': ids,
        'participantNames': {
          currentUser.uid: currentUserName,
          peerId: peerName,
        },
        'participantImages': {
          currentUser.uid: currentUserImage,
          peerId: peerImage,
        },
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => ChatScreen(
                peerId: peerId,
                peerName: peerName.isEmpty ? ' ' : peerName,
              ),
        ),
      );
    } catch (e) {
      _handleFeedback('Error: $e');
    }
  }

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

  Widget _buildPostCard({
    required String title,
    required String description,
    required String city,
    required String price,
    required String currency,
    required String posterName,
    required String posterImageUrl,
    required String postedBy,
    required Timestamp? createdAt,
    bool isBestMatch = false,
    Widget? topRight,
    Widget? trailing,
  }) {
    final cachedProfile = _profileCache[postedBy];
    final resolvedName =
        posterName.trim().isNotEmpty && posterName != 'User'
            ? posterName
            : (cachedProfile?['fullName']?.toString() ?? '');
    final resolvedImage =
        posterImageUrl.trim().isNotEmpty
            ? posterImageUrl
            : (cachedProfile?['imageUrl']?.toString() ?? '');

    final shouldFetch = resolvedName.isEmpty || resolvedImage.isEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future:
              shouldFetch
                  ? FirebaseFirestore.instance
                      .collection('profiles')
                      .doc(postedBy)
                      .get()
                  : null,
          builder: (context, snapshot) {
            final fetched = snapshot.data?.data();
            if (fetched != null) {
              _profileCache[postedBy] = fetched;
            }

            final finalName =
                resolvedName.isNotEmpty
                    ? resolvedName
                    : (fetched?['fullName']?.toString() ?? '');
            final finalImage =
                resolvedImage.isNotEmpty
                    ? resolvedImage
                    : (fetched?['imageUrl']?.toString() ?? '');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: postedBy),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            finalImage.isNotEmpty
                                ? NetworkImage(finalImage)
                                : null,
                        child:
                            finalImage.isEmpty
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              finalName.isEmpty ? ' ' : finalName,
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
                      if (topRight != null) topRight,
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (isBestMatch) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Best match',
                      style: TextStyle(
                        color: Color(0xFFB86E5D),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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
                    _smallInfo(Icons.location_on_outlined, city),
                    const SizedBox(width: 18),
                    _smallInfo(Icons.payments_outlined, '$price $currency'),
                  ],
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerRight, child: trailing),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _smallInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPostsList(
    List<QueryDocumentSnapshot> posts,
    User? currentUser,
    Map<String, dynamic>? currentUserProfile,
  ) {
    final postCards =
        posts.map((post) {
          final data = post.data() as Map<String, dynamic>;
          final postId = post.id;

          final title = (data['title'] ?? 'No Title').toString();
          final desc = (data['description'] ?? '').toString();
          final city = (data['city'] ?? 'Unknown').toString();
          final price = (data['price'] ?? 'N/A').toString();
          final currency = (data['currency'] ?? '\$').toString();
          final postedBy = (data['postedBy'] ?? '').toString();
          final createdAt = data['createdAt'] as Timestamp?;
          final posterName = (data['posterName'] ?? '').toString();
          final posterImageUrl = (data['posterImageUrl'] ?? '').toString();
          final matchScore =
              currentUserProfile == null
                  ? 0.0
                  : _calculateMatchScore(currentUserProfile, data);

          final isHiringPost = selectedType == 'job';

          final bool alreadyDone =
              isHiringPost
                  ? (_appliedStatus[postId] ?? false)
                  : (_requestedStatus[postId] ?? false);

          final bool isSaved = _savedStatus[postId] ?? false;
          final bool isOwnPost =
              postedBy == currentUser?.uid ||
              (data['userId'] ?? '').toString().trim() == currentUser?.uid;

          return _buildPostCard(
            title: title,
            description: desc,
            city: city,
            price: price,
            currency: currency,
            posterName: posterName,
            posterImageUrl: posterImageUrl,
            postedBy: postedBy,
            createdAt: createdAt,
            isBestMatch: !isOwnPost && matchScore >= _bestMatchThreshold,
            topRight: _buildPostHeaderActions(
              currentUser: currentUser,
              postId: postId,
              postData: data,
              isSaved: isSaved,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => _openChat(postedBy),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: const BorderSide(color: kPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Chat'),
                ),
                const SizedBox(width: 10),
                if (selectedType == 'job')
                  alreadyDone
                      ? ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          disabledBackgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 12,
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Applied'),
                      )
                      : ElevatedButton(
                        onPressed: () async {
                          final ok = await _ensureCompleteProfile(
                            action: 'apply',
                          );
                          if (!ok) return;

                          _showApplySheet(postId, title, postedBy);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 12,
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Apply'),
                      )
                else
                  alreadyDone
                      ? ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyPostsScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 12,
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Requested'),
                      )
                      : ElevatedButton(
                        onPressed: () async {
                          final ok = await _ensureCompleteProfile(
                            action: 'hire someone',
                          );
                          if (!ok) return;

                          _showHireSheet(postId, title, postedBy);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 12,
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Hire'),
                      ),
              ],
            ),
          );
        }).toList();

    return ListView(children: postCards);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('YallaHire', style: TextStyle(color: Colors.black)),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.bookmark_border, color: Colors.black),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedPostsScreen()),
            );
          },
        ),
        actions: [_buildNotificationsAction(currentUser)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                _typeToggleButton(label: 'Find Work', value: 'job'),
                const SizedBox(width: 12),
                _typeToggleButton(label: 'Hire Someone', value: 'service'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('posts')
                      .where('type', isEqualTo: selectedType)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Firestore error:\n${snapshot.error}',
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
                  return Center(
                    child: Text(
                      selectedType == 'job'
                          ? 'No hiring posts yet.'
                          : 'No work posts yet.',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }

                if (currentUser == null) {
                  posts.sort((a, b) {
                    final at =
                        (a.data() as Map<String, dynamic>)['createdAt']
                            as Timestamp?;
                    final bt =
                        (b.data() as Map<String, dynamic>)['createdAt']
                            as Timestamp?;
                    final aMs = at?.millisecondsSinceEpoch ?? 0;
                    final bMs = bt?.millisecondsSinceEpoch ?? 0;
                    return bMs.compareTo(aMs);
                  });

                  return _buildPostsList(posts, currentUser, null);
                }

                return FutureBuilder<Map<String, dynamic>>(
                  future: _getCurrentUserProfile(currentUser),
                  builder: (context, profileSnapshot) {
                    if (profileSnapshot.connectionState !=
                            ConnectionState.done &&
                        !profileSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: kPrimary),
                      );
                    }

                    final currentUserProfile = profileSnapshot.data ?? {};

                    posts.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aScore = _calculateMatchScore(
                        currentUserProfile,
                        aData,
                      );
                      final bScore = _calculateMatchScore(
                        currentUserProfile,
                        bData,
                      );

                      final scoreCompare = bScore.compareTo(aScore);
                      if (scoreCompare != 0) return scoreCompare;

                      final at = aData['createdAt'] as Timestamp?;
                      final bt = bData['createdAt'] as Timestamp?;
                      final aMs = at?.millisecondsSinceEpoch ?? 0;
                      final bMs = bt?.millisecondsSinceEpoch ?? 0;
                      return bMs.compareTo(aMs);
                    });

                    return FutureBuilder<void>(
                      future: _prepareVisiblePostStates(
                        posts: posts,
                        userId: currentUser.uid,
                        isHiringPost: selectedType == 'job',
                      ),
                      builder: (context, prepSnapshot) {
                        if (prepSnapshot.connectionState !=
                                ConnectionState.done &&
                            _preparedPostsKey.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(color: kPrimary),
                          );
                        }

                        return _buildPostsList(
                          posts,
                          currentUser,
                          currentUserProfile,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
