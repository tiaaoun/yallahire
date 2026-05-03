import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

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

  Widget _buildStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          Icons.star,
          size: 16,
          color: index < rating ? Colors.amber : Colors.grey.shade300,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('profiles')
            .doc(userId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(child: Text("Profile not found"));
          }

          final name = (data['fullName'] ?? '').toString();
          final imageUrl = (data['imageUrl'] ?? '').toString();
          final city = (data['city'] ?? '').toString();
          final occupation = (data['occupation'] ?? '').toString();
          final bio = (data['bio'] ?? '').toString();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('profiles')
                .doc(userId)
                .collection('reviews')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, reviewSnapshot) {
              final reviewDocs = reviewSnapshot.data?.docs ?? [];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                        child: imageUrl.isEmpty
                            ? Icon(Icons.person, size: 40, color: Colors.grey)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        occupation,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (city.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18),
                          const SizedBox(width: 6),
                          Text(city),
                        ],
                      ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "About",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(bio),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      "Reviews",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (reviewSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        reviewDocs.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else if (reviewDocs.isEmpty)
                      const Text(
                        "No reviews yet.",
                        style: TextStyle(color: Colors.black54),
                      )
                    else
                      Column(
                        children: reviewDocs.map((doc) {
                          final review =
                              doc.data() as Map<String, dynamic>? ?? {};
                          final fromName =
                              (review['fromName'] ?? 'User').toString();
                          final comment = (review['comment'] ?? '').toString();
                          final rating = review['rating'] is int
                              ? review['rating'] as int
                              : int.tryParse('${review['rating']}') ?? 0;
                          final createdAt = review['createdAt'] as Timestamp?;
                          final tags = (review['tags'] as List<dynamic>? ?? [])
                              .map((e) => e.toString())
                              .where((e) => e.isNotEmpty)
                              .toList();

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        fromName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _timeAgo(createdAt),
                                      style: const TextStyle(
                                        color: Colors.black45,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildStars(rating),
                                if (comment.trim().isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    comment,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                                if (tags.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: tags.map((tag) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF4F1),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          tag,
                                          style: const TextStyle(
                                            color: Color(0xFFB86E5D),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
