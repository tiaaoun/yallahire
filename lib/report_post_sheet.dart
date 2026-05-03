import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_feedback.dart';
import 'notification_service.dart';

Future<void> showReportPostSheet(
  BuildContext context, {
  required String postId,
  required String postTitle,
  required String postOwnerUid,
  required String postOwnerName,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    await showAppMessageDialog(
      context,
      title: 'Sign in required',
      message: 'Please log in to report posts.',
    );
    return;
  }

  if (user.uid == postOwnerUid) {
    await showAppMessageDialog(
      context,
      title: 'Unavailable',
      message: 'You cannot report your own post.',
    );
    return;
  }

  const reasons = [
    'Spam or scam',
    'Inappropriate content',
    'Unsafe request',
    'Harassment or hate speech',
    'Other',
  ];

  String? selectedReason;
  String? reasonError;
  final detailsController = TextEditingController();
  late void Function(VoidCallback fn) updateSheetState;

  Future<void> submitReport({
    required BuildContext parentContext,
    required BuildContext sheetContext,
  }) async {
    print("Submit tapped");

    if ((selectedReason ?? '').trim().isEmpty) {
      updateSheetState(
        () => reasonError = 'Please select a reason before submitting.',
      );
      return;
    }

    updateSheetState(() => reasonError = null);

    try {
      final reportId = '${postId}_${user.uid}';
      final reportRef = FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId);

      final reporterProfile =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(user.uid)
              .get();
      final reporterName =
          (reporterProfile.data()?['fullName'] ?? 'User').toString();

      await reportRef.set({
        'postId': postId,
        'postTitle': postTitle,
        'postOwnerUid': postOwnerUid,
        'postOwnerName': postOwnerName,
        'reportedByUid': user.uid,
        'reportedByName': reporterName,
        'reason': selectedReason,
        'details': detailsController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));

      await AppNotificationService.notifyAdmins(
        title: 'New report submitted',
        message: 'A new report was submitted.',
        relatedPostId: postId,
      );

      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
    } catch (e) {
      print(e);
    }
  }

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (innerContext, setSheetState) {
          updateSheetState = setSheetState;

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
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
                  const SizedBox(height: 16),
                  const Text(
                    'Report Post',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    postTitle,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Reason',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        reasons.map((reason) {
                          final isSelected = selectedReason == reason;
                          return ChoiceChip(
                            label: Text(reason),
                            selected: isSelected,
                            onSelected: (_) {
                              setSheetState(() {
                                selectedReason = reason;
                                reasonError = null;
                              });
                            },
                            selectedColor: const Color(0xFFFFE6E0),
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(
                              color:
                                  isSelected
                                      ? const Color(0xFFF0B8AB)
                                      : Colors.transparent,
                            ),
                            labelStyle: TextStyle(
                              color:
                                  isSelected
                                      ? const Color(0xFFB86E5D)
                                      : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          );
                        }).toList(),
                  ),
                  if (reasonError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      reasonError!,
                      style: const TextStyle(
                        color: Color(0xFFB86E5D),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: detailsController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Details (optional)',
                      labelStyle: const TextStyle(color: Colors.black54),
                      floatingLabelStyle: const TextStyle(
                        color: Color(0xFFE89C8A),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFFE89C8A),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          () => submitReport(
                            parentContext: context,
                            sheetContext: sheetContext,
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE89C8A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text(
                        'Submit Report',
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
