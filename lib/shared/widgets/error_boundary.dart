import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../core/constants/app_colors.dart';

/// Replaces Flutter's default red-screen-of-death (in debug) and the
/// blank grey area (in release) with a friendly, branded fallback the
/// user can recover from.
///
/// Drop one of these at the top of the widget tree (e.g. wrap each
/// route's body) — whenever a descendant throws during build, the
/// boundary catches it via [ErrorWidget.builder] and shows the fallback.
///
/// All caught errors are forwarded to Crashlytics so we still see them.
///
/// Use [ErrorBoundary.install] once at app startup to register the
/// global handler. Individual widgets that opt in get the fallback;
/// everything else falls through to Flutter's default behaviour.
class ErrorBoundary {
  ErrorBoundary._();

  static bool _installed = false;

  /// Install the global error widget builder. Call from main() once.
  static void install() {
    if (_installed) return;
    _installed = true;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Forward to Crashlytics (web is a no-op).
      if (!kIsWeb) {
        try {
          FirebaseCrashlytics.instance.recordFlutterError(details);
        } catch (_) {/* silent */}
      } else {
        debugPrint('[ErrorBoundary] ${details.exceptionAsString()}');
      }
      return _Fallback(details: details);
    };
  }
}

class _Fallback extends StatelessWidget {
  final FlutterErrorDetails details;
  const _Fallback({required this.details});

  @override
  Widget build(BuildContext context) {
    // The fallback might be rendered above a Material ancestor (route
    // body) OR at the root before MaterialApp exists. Wrap defensively
    // so it always renders, regardless of context.
    return Material(
      color: const Color(0xFFF7F7F7),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This screen ran into a problem. The error has been '
                  'reported. Please go back and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      details.exceptionAsString(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.error,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
