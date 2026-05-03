import 'package:flutter/material.dart';

class PostActionMenuItemData {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const PostActionMenuItemData({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class PostActionMenuButton extends StatelessWidget {
  final List<PostActionMenuItemData> items;
  final ValueChanged<String> onSelected;

  const PostActionMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      tooltip: 'Post options',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 10,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      constraints: const BoxConstraints(minWidth: 160),
      itemBuilder: (context) {
        return items.map((item) {
          return PopupMenuItem<String>(
            value: item.value,
            height: 42,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 18, color: item.color),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    color: item.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3D3CB)),
        ),
        child: const Icon(Icons.more_horiz, size: 18, color: Color(0xFFB86E5D)),
      ),
    );
  }
}
