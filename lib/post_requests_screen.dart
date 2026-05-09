import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_feedback.dart';
import 'chat_screen.dart';
import 'notification_service.dart';
import 'user_profile_screen.dart';

class PostRequestsScreen extends StatelessWidget {
  final String postId;
  final String postTitle;
  final bool isJobPost;

  const PostRequestsScreen({
    super.key,
    required this.postId,
    required this.postTitle,
    required this.isJobPost,
  });

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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFFF7D8D1);
      case 'rejected':
        return const Color(0xFFFCEAEA);
      case 'completed':
        return const Color(0xFFEFEFEF);
      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFFB86E5D);
      case 'rejected':
        return const Color(0xFFC35B5B);
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

  Future<void> _showMessageDialog(
    BuildContext context,
    String message, {
    String title = 'Notice',
  }) {
    return showAppMessageDialog(context, title: title, message: message);
  }

  Future<bool> _showRequestCompletionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Request completion?',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
          ),
          content: const Text(
            'Are you sure you want to request completion for this task?',
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
    );

    return result ?? false;
  }

  void _openUserProfile(BuildContext context, String userId) {
    if (userId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    );
  }

  Future<void> _updateStatus({
    required BuildContext context,
    required String docId,
    required String collectionName,
    required String newStatus,
    required String peerId,
    required String peerName,
    required String currentUserId,
  }) async {
    try {
      final requestRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection(collectionName)
          .doc(docId);
      if (newStatus == 'accepted' &&
          peerId.isNotEmpty &&
          currentUserId.isNotEmpty) {
        if (isJobPost) {
          // job posts can have only one active accepted applicant at a time.
          await requestRef.update({
            'status': 'accepted',
            'interactionStatus': 'in_progress',
            'completionRequested': false,
            'completionRequestedBy': null,
            'completionRequestedAt': null,
            'completedAt': null,
            'confirmedCompletedBy': null,
            'reviewedByPoster': false,
            'reviewedByOtherUser': false,
          });

          final postRef = FirebaseFirestore.instance
              .collection('posts')
              .doc(postId);

          await postRef.update({
            'status': 'in_progress',
            'assignedTo': peerId,
            'assignedToName': peerName,
            'acceptedRequestId': docId,
          });

          final pendingSnapshot =
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .collection(collectionName)
                  .where('status', isEqualTo: 'pending')
                  .get();

          for (final requestDoc in pendingSnapshot.docs) {
            if (requestDoc.id != docId) {
              // reject the remaining pending requests once one user is accepted.
              await requestDoc.reference.update({'status': 'rejected'});
            }
          }
        } else {
          final allServiceRequests =
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .collection(collectionName)
                  .get();

          final anotherActiveRequestExists = allServiceRequests.docs.any((d) {
            if (d.id == docId) return false;
            final data = d.data();
            final status = (data['status'] ?? '').toString().toLowerCase();
            final interactionStatus =
                (data['interactionStatus'] ?? '').toString().toLowerCase();

            return status == 'accepted' && interactionStatus == 'in_progress';
          });

          if (anotherActiveRequestExists) {
            if (!context.mounted) return;
            await _showMessageDialog(
              context,
              'Finish the current service request before accepting another one.',
            );
            return;
          }

          // service posts also move the accepted request into the in-progress stage.
          await requestRef.update({
            'status': 'accepted',
            'interactionStatus': 'in_progress',
            'completionRequested': false,
            'completionRequestedBy': null,
            'completionRequestedAt': null,
            'completedAt': null,
            'confirmedCompletedBy': null,
            'reviewedByPoster': false,
            'reviewedByOtherUser': false,
          });

          final pendingSnapshot =
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .collection(collectionName)
                  .where('status', isEqualTo: 'pending')
                  .get();

          for (final requestDoc in pendingSnapshot.docs) {
            if (requestDoc.id != docId) {
              await requestDoc.reference.update({'status': 'rejected'});
            }
          }
        }

        final ids = [currentUserId, peerId]..sort();
        // reuse the same deterministic chat ID pattern after an application is accepted.
        final chatId = '${ids[0]}_${ids[1]}';
        final chatRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId);

        final systemText =
            isJobPost
                ? 'Great news — your application for "$postTitle" was accepted. You can now chat here to coordinate the next steps.'
                : 'Great news — your hire request for "$postTitle" was accepted. You can now chat here to coordinate the next steps.';

        final currentProfileDoc =
            await FirebaseFirestore.instance
                .collection('profiles')
                .doc(currentUserId)
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

        final finalPeerName =
            peerName.trim().isNotEmpty
                ? peerName.trim()
                : (peerProfile['fullName'] ?? '').toString().trim();
        final peerImage = (peerProfile['imageUrl'] ?? '').toString().trim();

        await chatRef.set({
          'participants': ids,
          'participantNames': {
            currentUserId: currentUserName,
            peerId: finalPeerName,
          },
          'participantImages': {
            currentUserId: currentUserImage,
            peerId: peerImage,
          },
          'lastMessage': systemText,
          'lastUpdated': FieldValue.serverTimestamp(),
          'unreadCount': {currentUserId: 0, peerId: 1},
        }, SetOptions(merge: true));

        if (!context.mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => ChatScreen(
                  peerId: peerId,
                  peerName: finalPeerName.isEmpty ? ' ' : finalPeerName,
                ),
          ),
        );

        try {
          // add a single system message so the accepted interaction has a clear chat starting point.
          final existingSystemMessages =
              await chatRef
                  .collection('messages')
                  .where('type', isEqualTo: 'system')
                  .where('text', isEqualTo: systemText)
                  .limit(1)
                  .get();

          if (existingSystemMessages.docs.isEmpty) {
            await chatRef.collection('messages').add({
              'senderId': 'system',
              'receiverId': peerId,
              'text': systemText,
              'timestamp': FieldValue.serverTimestamp(),
              'seen': false,
              'type': 'system',
            });
          }
        } catch (_) {}

        await AppNotificationService.createNotification(
          userId: peerId,
          type: 'application_accepted',
          title: 'Application accepted',
          message:
              isJobPost
                  ? 'Your application for $postTitle was accepted.'
                  : 'Your request for $postTitle was accepted.',
          relatedPostId: postId,
          relatedChatId: chatId,
          relatedPeerId: currentUserId,
          relatedPeerName: currentUserName.isEmpty ? 'User' : currentUserName,
        );

        return;
      }

      await requestRef.update({'status': newStatus});

      if (newStatus == 'rejected' && peerId.isNotEmpty) {
        await AppNotificationService.createNotification(
          userId: peerId,
          type: 'application_rejected',
          title: 'Application update',
          message:
              isJobPost
                  ? 'Your application for $postTitle was rejected.'
                  : 'Your request for $postTitle was rejected.',
          relatedPostId: postId,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      await _showMessageDialog(context, 'Accept failed: $e', title: 'Error');
    }
  }

  Future<void> _requestCompletion({
    required BuildContext context,
    required String docId,
    required String collectionName,
    required String currentUserId,
  }) async {
    final shouldContinue = await _showRequestCompletionDialog(context);
    if (!shouldContinue) return;

    try {
      final requestRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection(collectionName)
          .doc(docId);

      await requestRef.update({
        'completionRequested': true,
        'completionRequestedBy': currentUserId,
        'completionRequestedAt': FieldValue.serverTimestamp(),
      });

      final requestDoc = await requestRef.get();
      final data = requestDoc.data() ?? {};
      final postOwnerUid = (data['postOwnerUid'] ?? '').toString();
      final recipientUid =
          currentUserId == postOwnerUid
              ? (isJobPost
                  ? (data['applicantUid'] ?? '').toString()
                  : (data['hirerUid'] ?? '').toString())
              : postOwnerUid;

      final actorProfile =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(currentUserId)
              .get();
      final actorName =
          (actorProfile.data()?['fullName'] ?? 'Someone').toString();

      await AppNotificationService.createNotification(
        userId: recipientUid,
        type: 'completion_request',
        title: 'Completion request',
        message: '$actorName requested to mark $postTitle as completed.',
        relatedPostId: postId,
      );
    } catch (e) {
      if (!context.mounted) return;
      await _showMessageDialog(context, 'Error: $e', title: 'Error');
    }
  }

  Future<void> _confirmCompletion({
    required BuildContext context,
    required String docId,
    required String collectionName,
    required String currentUserId,
  }) async {
    try {
      final requestRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection(collectionName)
          .doc(docId);

      await requestRef.update({
        'interactionStatus': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'confirmedCompletedBy': currentUserId,
      });

      final requestDoc = await requestRef.get();
      final data = requestDoc.data() ?? {};
      final postOwnerUid = (data['postOwnerUid'] ?? '').toString();
      final otherUid =
          isJobPost
              ? (data['applicantUid'] ?? '').toString()
              : (data['hirerUid'] ?? '').toString();

      if (postOwnerUid.isNotEmpty) {
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
    } catch (e) {
      if (!context.mounted) return;
      await _showMessageDialog(context, 'Error: $e', title: 'Error');
    }
  }

  Future<void> _submitReview({
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

    await reviewRef.set({
      'fromUid': currentUserId,
      'fromName': fromName,
      'toUid': toUid,
      'postId': postId,
      'requestId': docId,
      'postTitle': postTitle,
      'collectionName': collectionName,
      'rating': rating,
      'comment': comment.trim(),
      'tags': tags,
      'role': isPoster ? 'poster_to_other' : 'other_to_poster',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await requestRef.update({
      isPoster ? 'reviewedByPoster' : 'reviewedByOtherUser': true,
    });
  }

  Future<void> _showReviewSheet({
    required BuildContext context,
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
                          } catch (e) {
                            if (!context.mounted) return;
                            await _showMessageDialog(
                              context,
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

  void _openChat(
    BuildContext context, {
    required String peerId,
    required String peerName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(peerId: peerId, peerName: peerName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collectionName = isJobPost ? 'applications' : 'hireRequests';
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isJobPost ? 'Applicants' : 'Hire Requests',
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              postTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('posts')
                      .doc(postId)
                      .collection(collectionName)
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

                final docs = snapshot.data?.docs ?? [];

                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;

                  final aTime =
                      isJobPost
                          ? aData['appliedAt'] as Timestamp?
                          : aData['createdAt'] as Timestamp?;
                  final bTime =
                      isJobPost
                          ? bData['appliedAt'] as Timestamp?
                          : bData['createdAt'] as Timestamp?;

                  final aMs = aTime?.millisecondsSinceEpoch ?? 0;
                  final bMs = bTime?.millisecondsSinceEpoch ?? 0;

                  return bMs.compareTo(aMs);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      isJobPost
                          ? 'No applicants yet.'
                          : 'No hire requests yet.',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;

                    final peerId =
                        isJobPost
                            ? (data['applicantUid'] ?? '').toString()
                            : (data['hirerUid'] ?? '').toString();

                    final name =
                        isJobPost
                            ? (data['applicantName'] ?? 'User').toString()
                            : (data['hirerName'] ?? 'User').toString();

                    final imageUrl =
                        isJobPost
                            ? (data['applicantImageUrl'] ?? '').toString()
                            : (data['hirerImageUrl'] ?? '').toString();

                    final occupation =
                        isJobPost
                            ? (data['applicantOccupation'] ?? '').toString()
                            : (data['hirerOccupation'] ?? '').toString();

                    final city =
                        isJobPost
                            ? (data['applicantCity'] ?? '').toString()
                            : (data['hirerCity'] ?? '').toString();

                    final phone =
                        isJobPost
                            ? (data['applicantPhone'] ?? '').toString()
                            : (data['hirerPhone'] ?? '').toString();

                    final gender =
                        isJobPost
                            ? (data['applicantGender'] ?? '').toString()
                            : (data['hirerGender'] ?? '').toString();

                    final birthYear =
                        isJobPost
                            ? (data['applicantBirthYear'] ?? '').toString()
                            : (data['hirerBirthYear'] ?? '').toString();

                    final message = (data['message'] ?? '').toString().trim();
                    final status = (data['status'] ?? 'pending').toString();
                    final interactionStatus =
                        (data['interactionStatus'] ?? '').toString();
                    final completionRequested =
                        data['completionRequested'] == true;
                    final completionRequestedBy =
                        (data['completionRequestedBy'] ?? '').toString();
                    final reviewedByPoster = data['reviewedByPoster'] == true;
                    final reviewedByOtherUser =
                        data['reviewedByOtherUser'] == true;
                    final postOwnerUid =
                        (data['postOwnerUid'] ?? '').toString();

                    final createdAt =
                        isJobPost
                            ? data['appliedAt'] as Timestamp?
                            : data['createdAt'] as Timestamp?;

                    final isPending = status.toLowerCase() == 'pending';
                    final isAccepted = status.toLowerCase() == 'accepted';
                    final isInProgress =
                        interactionStatus.toLowerCase() == 'in_progress';
                    final isCompleted =
                        interactionStatus.toLowerCase() == 'completed';
                    final isRequester = completionRequestedBy == currentUserId;
                    final isPoster = currentUserId == postOwnerUid;

                    final canConfirmCompletion =
                        isAccepted &&
                        isInProgress &&
                        completionRequested &&
                        completionRequestedBy.isNotEmpty &&
                        !isRequester;

                    final hasReviewed =
                        isPoster ? reviewedByPoster : reviewedByOtherUser;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
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
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap:
                                        () => _openUserProfile(context, peerId),
                                    behavior: HitTestBehavior.opaque,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: Colors.grey.shade200,
                                          backgroundImage:
                                              imageUrl.isNotEmpty
                                                  ? NetworkImage(imageUrl)
                                                  : null,
                                          child:
                                              imageUrl.isEmpty
                                                  ? Icon(
                                                    Icons.person,
                                                    color: Colors.grey.shade500,
                                                  )
                                                  : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _timeAgo(createdAt),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black45,
                                                ),
                                              ),
                                              if (occupation.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  occupation,
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ],
                                              if (city.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  city,
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ],
                                              if (phone.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  phone,
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ],
                                              if (gender.isNotEmpty ||
                                                  birthYear.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  [
                                                    if (gender.isNotEmpty)
                                                      gender,
                                                    if (birthYear.isNotEmpty)
                                                      birthYear,
                                                  ].join(' • '),
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildStatusChip(
                                  isCompleted ? 'completed' : status,
                                ),
                              ],
                            ),
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Text(
                                  message,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (isPending)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed:
                                        () => _updateStatus(
                                          context: context,
                                          docId: docId,
                                          collectionName: collectionName,
                                          newStatus: 'rejected',
                                          peerId: peerId,
                                          peerName: name,
                                          currentUserId: currentUserId,
                                        ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                      side: BorderSide(
                                        color: Colors.red.shade300,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed:
                                        () => _updateStatus(
                                          context: context,
                                          docId: docId,
                                          collectionName: collectionName,
                                          newStatus: 'accepted',
                                          peerId: peerId,
                                          peerName: name,
                                          currentUserId: currentUserId,
                                        ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kPrimary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                    child: const Text('Accept'),
                                  ),
                                ],
                              )
                            else if (isAccepted && isInProgress)
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed:
                                        peerId.isEmpty
                                            ? null
                                            : () => _openChat(
                                              context,
                                              peerId: peerId,
                                              peerName: name,
                                            ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: kPrimary,
                                      side: const BorderSide(color: kPrimary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                    child: const Text('Chat'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed:
                                          completionRequested
                                              ? null
                                              : () => _requestCompletion(
                                                context: context,
                                                docId: docId,
                                                collectionName: collectionName,
                                                currentUserId: currentUserId,
                                              ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            completionRequested
                                                ? Colors.grey.shade300
                                                : kPrimary,
                                        foregroundColor:
                                            completionRequested
                                                ? Colors.black54
                                                : Colors.white,
                                        disabledBackgroundColor:
                                            Colors.grey.shade300,
                                        disabledForegroundColor: Colors.black54,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        completionRequested
                                            ? (isRequester
                                                ? 'Request Pending'
                                                : 'Completion Requested')
                                            : 'Request Completion',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (canConfirmCompletion) ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed:
                                          () => _confirmCompletion(
                                            context: context,
                                            docId: docId,
                                            collectionName: collectionName,
                                            currentUserId: currentUserId,
                                          ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Confirm'),
                                    ),
                                  ],
                                ],
                              )
                            else if (isCompleted)
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed:
                                        peerId.isEmpty
                                            ? null
                                            : () => _openChat(
                                              context,
                                              peerId: peerId,
                                              peerName: name,
                                            ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: kPrimary,
                                      side: const BorderSide(color: kPrimary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                    child: const Text('Chat'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed:
                                          hasReviewed
                                              ? null
                                              : () => _showReviewSheet(
                                                context: context,
                                                docId: docId,
                                                collectionName: collectionName,
                                                toUid: peerId,
                                                isPosterReviewing: isPoster,
                                              ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            hasReviewed
                                                ? Colors.grey.shade300
                                                : kPrimary,
                                        foregroundColor:
                                            hasReviewed
                                                ? Colors.black54
                                                : Colors.white,
                                        disabledBackgroundColor:
                                            Colors.grey.shade300,
                                        disabledForegroundColor: Colors.black54,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        hasReviewed
                                            ? 'Review Submitted'
                                            : 'Leave Review',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed:
                                        peerId.isEmpty
                                            ? null
                                            : () => _openChat(
                                              context,
                                              peerId: peerId,
                                              peerName: name,
                                            ),
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
                              ),
                          ],
                        ),
                      ),
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
