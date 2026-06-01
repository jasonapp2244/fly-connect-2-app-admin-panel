import 'package:cloud_firestore/cloud_firestore.dart';

/// Pure logic and Firestore-only helpers for the GDPR admin page.
///
/// Extracted from `admin_gdpr_page.dart` so the data assembly (which
/// fans out across 7+ collections) can be unit-tested against
/// `fake_cloud_firestore` without bringing in the whole widget tree.
///
/// Anything UI-shaped stays in `admin_gdpr_page.dart`; anything that
/// just shuffles maps/lists belongs here.

/// Filter keys understood by [applyGdprFilter] / [GdprStatusCounts].
/// Kept as a sealed enum so the widget's filter-pill list and the
/// logic stay in lock-step.
enum GdprFilter {
  all,
  export,
  delete,
  pending,
  completed,
}

/// Maps the raw string filter coming from the UI to the enum. Anything
/// unknown collapses to [GdprFilter.all] — the safe default that hides
/// nothing from the admin.
GdprFilter parseGdprFilter(String raw) {
  switch (raw) {
    case 'export': return GdprFilter.export;
    case 'delete': return GdprFilter.delete;
    case 'pending': return GdprFilter.pending;
    case 'completed': return GdprFilter.completed;
    default: return GdprFilter.all;
  }
}

/// Apply the active filter to the full list of GDPR request maps.
/// Treats missing keys as the most-permissive interpretation
/// (a request with no `status` shows up under "pending").
List<Map<String, dynamic>> applyGdprFilter(
    List<Map<String, dynamic>> requests, GdprFilter f) {
  switch (f) {
    case GdprFilter.export:
      return requests.where((r) => r['requestType'] == 'export').toList();
    case GdprFilter.delete:
      return requests.where((r) => r['requestType'] == 'delete').toList();
    case GdprFilter.pending:
      return requests
          .where((r) => (r['status'] ?? 'pending') == 'pending')
          .toList();
    case GdprFilter.completed:
      return requests.where((r) => r['status'] == 'completed').toList();
    case GdprFilter.all:
      return List<Map<String, dynamic>>.from(requests);
  }
}

/// Pre-computed status counts for the stat cards at the top of the page.
class GdprStatusCounts {
  final int pending;
  final int processing;
  final int completed;
  final int total;

  const GdprStatusCounts({
    required this.pending,
    required this.processing,
    required this.completed,
    required this.total,
  });

  factory GdprStatusCounts.from(List<Map<String, dynamic>> reqs) {
    int p = 0, pr = 0, c = 0;
    for (final r in reqs) {
      switch (r['status']) {
        case 'pending':
        case null:
          p++; break;
        case 'processing':
          pr++; break;
        case 'completed':
          c++; break;
      }
    }
    return GdprStatusCounts(
      pending: p, processing: pr, completed: c, total: reqs.length,
    );
  }
}

/// Human "x minutes/hours/days ago" string. [now] is injectable for
/// deterministic tests.
String formatTimeAgo(DateTime when, {DateTime Function()? now}) {
  final n = (now ?? DateTime.now)();
  final diff = n.difference(when);
  if (diff.isNegative) return 'just now';
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Collects a single user's data into a JSON-safe map ready to be
/// `jsonEncode`d and uploaded as their GDPR "right to access" export.
///
/// Reads from:
///   • `users/{userId}` — the profile doc
///   • `users/{userId}/{following,followers,blocked,trips}` subcollections
///   • `posts.where(authorId == userId)` — capped at 500
///   • `safeChecks.where(userId == userId)` — capped at 500
///   • `matches.where(userA == userId)` + matches.where(userB == userId)`
///   • `reports.where(reporterId == userId)`
///   • `audit_log.where(targetId == userId)`
///
/// Why a flat function: the original implementation lived inline in
/// `_AdminGdprPageState._compileExport` and was untestable without
/// mounting the whole widget. Pulled out so we can fake-Firestore it.
///
/// Returns a map ready for `normaliseForJson` → `jsonEncode`. Values
/// inside may still contain Firestore-native types (Timestamp, etc.) —
/// that's the normaliser's job, not this one's.
Future<Map<String, dynamic>> buildUserExportData(
  FirebaseFirestore db,
  String userId, {
  DateTime Function()? now,
}) async {
  final stamp = (now ?? DateTime.now)().toIso8601String();
  final export = <String, dynamic>{
    'exportGeneratedAt': stamp,
    'userId': userId,
  };

  // 1. Top-level user doc
  final userDoc = await db.collection('users').doc(userId).get();
  export['user'] = userDoc.data();

  // 2. Subcollections under the user doc
  for (final sub in const ['following', 'followers', 'blocked', 'trips']) {
    final snap =
        await db.collection('users').doc(userId).collection(sub).get();
    export[sub] =
        snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // 3. Posts authored by this user
  final postsSnap = await db.collection('posts')
      .where('authorId', isEqualTo: userId).limit(500).get();
  export['posts'] =
      postsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

  // 4. SafeCheck history
  final scSnap = await db.collection('safeChecks')
      .where('userId', isEqualTo: userId).limit(500).get();
  export['safeChecks'] =
      scSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

  // 5. Matches involving this user (both sides)
  final matchSnapA = await db.collection('matches')
      .where('userA', isEqualTo: userId).limit(500).get();
  final matchSnapB = await db.collection('matches')
      .where('userB', isEqualTo: userId).limit(500).get();
  export['matches'] = [
    ...matchSnapA.docs.map((d) => {'id': d.id, ...d.data()}),
    ...matchSnapB.docs.map((d) => {'id': d.id, ...d.data()}),
  ];

  // 6. Reports filed BY this user (so they can see what they reported)
  final reportsSnap = await db.collection('reports')
      .where('reporterId', isEqualTo: userId).limit(500).get();
  export['reportsFiled'] =
      reportsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

  // 7. Audit actions affecting this user
  final auditSnap = await db.collection('audit_log')
      .where('targetId', isEqualTo: userId).limit(500).get();
  export['auditEntriesAboutMe'] =
      auditSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

  return export;
}
