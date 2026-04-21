import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Shared confirmation dialog for destructive actions.
///
/// Returns `true` when the user confirms, `false` otherwise.
///
/// Example:
/// ```dart
/// final ok = await showConfirmDialog(
///   context,
///   title: 'Logout?',
///   message: 'You will need to sign in again.',
///   confirmLabel: 'Logout',
///   isDestructive: true,
/// );
/// if (ok) await auth.logout();
/// ```
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: Text(message,
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDestructive ? AppColors.error : AppColors.primary,
            foregroundColor:
                isDestructive ? Colors.white : AppColors.dark,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return result ?? false;
}
