import 'package:flutter/material.dart';

Future<void> showAppMessageDialog(
  BuildContext context, {
  required String message,
  String title = 'Notice',
}) async {
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.black87, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK', style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
  );
}
