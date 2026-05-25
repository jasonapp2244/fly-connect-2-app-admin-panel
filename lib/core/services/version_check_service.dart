import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Force-update + soft-update gate.
///
/// On app launch, compares the running build number against a Firestore
/// document we control:
///
///   config/app_version
///     ├── minSupportedBuild  (int)   — anything below this is REQUIRED to update
///     ├── latestBuild        (int)   — recommended-update target
///     ├── storeUrlAndroid    (String)
///     ├── storeUrlIos        (String)
///     └── outageMessage      (String, optional) — display as banner if non-empty
///
/// The remote doc can be edited in the Firebase Console without
/// shipping a new app build — letting us force updates when we need
/// to roll out a critical security patch.
///
/// If the doc is missing or unreachable, the service degrades silently
/// (does NOT block the user). This is intentional — better to risk
/// running an old client than to lock everyone out if Firestore hiccups.
class VersionCheckService {
  VersionCheckService._();
  static final VersionCheckService instance = VersionCheckService._();

  VersionCheckResult? _last;
  VersionCheckResult? get last => _last;

  Future<VersionCheckResult> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final snap = await FirebaseFirestore.instance
          .collection('config')
          .doc('app_version')
          .get();

      if (!snap.exists) {
        return _last = VersionCheckResult.ok(currentBuild);
      }

      final d = snap.data() ?? <String, dynamic>{};
      final minBuild = (d['minSupportedBuild'] as num?)?.toInt() ?? 0;
      final latest = (d['latestBuild'] as num?)?.toInt() ?? currentBuild;
      final urlAndroid = (d['storeUrlAndroid'] as String?) ?? '';
      final urlIos = (d['storeUrlIos'] as String?) ?? '';
      final outageMessage = (d['outageMessage'] as String?) ?? '';

      if (currentBuild < minBuild) {
        return _last = VersionCheckResult(
          status: VersionStatus.forceUpdate,
          currentBuild: currentBuild,
          latestBuild: latest,
          storeUrlAndroid: urlAndroid,
          storeUrlIos: urlIos,
          outageMessage: outageMessage,
        );
      }
      if (currentBuild < latest) {
        return _last = VersionCheckResult(
          status: VersionStatus.softUpdate,
          currentBuild: currentBuild,
          latestBuild: latest,
          storeUrlAndroid: urlAndroid,
          storeUrlIos: urlIos,
          outageMessage: outageMessage,
        );
      }
      return _last = VersionCheckResult.ok(currentBuild,
          outageMessage: outageMessage);
    } catch (e) {
      debugPrint('[VersionCheck] failed: $e');
      // Fail open — never lock the user out due to a transient error.
      return _last = VersionCheckResult.ok(0);
    }
  }
}

enum VersionStatus { ok, softUpdate, forceUpdate }

class VersionCheckResult {
  final VersionStatus status;
  final int currentBuild;
  final int latestBuild;
  final String storeUrlAndroid;
  final String storeUrlIos;
  final String outageMessage;

  const VersionCheckResult({
    required this.status,
    required this.currentBuild,
    required this.latestBuild,
    required this.storeUrlAndroid,
    required this.storeUrlIos,
    required this.outageMessage,
  });

  factory VersionCheckResult.ok(int currentBuild,
          {String outageMessage = ''}) =>
      VersionCheckResult(
        status: VersionStatus.ok,
        currentBuild: currentBuild,
        latestBuild: currentBuild,
        storeUrlAndroid: '',
        storeUrlIos: '',
        outageMessage: outageMessage,
      );
}
