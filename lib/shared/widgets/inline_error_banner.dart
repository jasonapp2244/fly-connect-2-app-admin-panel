import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Compact error banner you can drop above any list/feed when the
/// underlying provider has captured a failure.
///
/// Different shape from [AsyncBoundary] on purpose:
///   • [AsyncBoundary] owns the Future / Stream lifecycle. Use it
///     where the screen has a single source of data and no other
///     UI to show while waiting.
///   • [InlineErrorBanner] is a passive widget that you conditionally
///     render when a [ChangeNotifier] provider exposes a non-null
///     error string. The screen can keep its existing skeleton +
///     empty-state UI; this just surfaces "something failed, want
///     to retry?" without taking over the whole screen.
class InlineErrorBanner extends StatelessWidget {
  /// Human-readable message. Keep short — this is a banner, not a dialog.
  final String message;

  /// Called when the user taps "Retry". Typically re-subscribes the
  /// stream or re-runs the failed load.
  final VoidCallback? onRetry;

  /// Optional dismiss handler. If null, no dismiss button is rendered
  /// (the banner stays up until the underlying error clears).
  final VoidCallback? onDismiss;

  /// In debug builds we tack the raw error string on so developers
  /// see what went wrong; in release we just show [message] (the
  /// raw text often leaks Firebase internals like collection paths).
  final Object? rawError;

  const InlineErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
    this.rawError,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Errors should be announced the moment they appear.
      liveRegion: true,
      container: true,
      label: 'Error: $message',
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline,
                  color: AppColors.error, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark)),
                  if (kDebugMode && rawError != null) ...[
                    const SizedBox(height: 2),
                    Text(rawError.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: AppColors.error)),
                  ],
                ],
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.dark,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close,
                    size: 18, color: AppColors.textSecondary),
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      ),
    );
  }
}
