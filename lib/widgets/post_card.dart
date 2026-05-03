import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostCard extends StatelessWidget {
  final String posterName;
  final String posterImageUrl;
  final Timestamp? createdAt;

  final String title;
  final String description;
  final String city;
  final String price;
  final String currency;

  final Widget? trailing;
  final Widget? topRight;
  final VoidCallback? onProfileTap;

  const PostCard({
    super.key,
    required this.posterName,
    required this.posterImageUrl,
    required this.createdAt,
    required this.title,
    required this.description,
    required this.city,
    required this.price,
    required this.currency,
    this.trailing,
    this.topRight,
    this.onProfileTap,
  });

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
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
          backgroundImage:
              posterImageUrl.isNotEmpty ? NetworkImage(posterImageUrl) : null,
          child: posterImageUrl.isEmpty
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
                posterName,
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
        if (topRight != null) topRight!,
      ],
    );

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onProfileTap != null)
              GestureDetector(
                onTap: onProfileTap,
                behavior: HitTestBehavior.opaque,
                child: header,
              )
            else
              header,
            const SizedBox(height: 10),
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
              Align(
                alignment: Alignment.centerRight,
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}