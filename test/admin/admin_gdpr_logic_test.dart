import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyconnect/features/admin/admin_gdpr_logic.dart';
import 'package:flyconnect/shared/utils/firestore_json.dart';

void main() {
  group('parseGdprFilter', () {
    test('maps known strings to enum values', () {
      expect(parseGdprFilter('export'), GdprFilter.export);
      expect(parseGdprFilter('delete'), GdprFilter.delete);
      expect(parseGdprFilter('pending'), GdprFilter.pending);
      expect(parseGdprFilter('completed'), GdprFilter.completed);
      expect(parseGdprFilter('all'), GdprFilter.all);
    });

    test('unknown values default to .all (safe default)', () {
      expect(parseGdprFilter(''), GdprFilter.all);
      expect(parseGdprFilter('asteroid'), GdprFilter.all);
    });
  });

  group('applyGdprFilter', () {
    final reqs = [
      {'id': '1', 'requestType': 'export', 'status': 'pending'},
      {'id': '2', 'requestType': 'export', 'status': 'completed'},
      {'id': '3', 'requestType': 'delete', 'status': 'pending'},
      {'id': '4', 'requestType': 'delete', 'status': 'processing'},
      {'id': '5', 'requestType': 'export'}, // no status → treated pending
    ];

    test('all returns a copy of the full list', () {
      final out = applyGdprFilter(reqs, GdprFilter.all);
      expect(out.length, 5);
      // Returned list is independent — mutating it shouldn't touch the input.
      out.clear();
      expect(reqs.length, 5);
    });

    test('export keeps only export requests', () {
      expect(applyGdprFilter(reqs, GdprFilter.export).map((r) => r['id']),
          ['1', '2', '5']);
    });

    test('delete keeps only delete requests', () {
      expect(applyGdprFilter(reqs, GdprFilter.delete).map((r) => r['id']),
          ['3', '4']);
    });

    test('pending includes requests with missing status', () {
      expect(applyGdprFilter(reqs, GdprFilter.pending).map((r) => r['id']),
          ['1', '3', '5']);
    });

    test('completed only matches explicit completed', () {
      expect(applyGdprFilter(reqs, GdprFilter.completed).map((r) => r['id']),
          ['2']);
    });
  });

  group('GdprStatusCounts.from', () {
    test('counts each status bucket; missing → pending', () {
      final c = GdprStatusCounts.from([
        {'status': 'pending'},
        {'status': 'pending'},
        {'status': 'processing'},
        {'status': 'completed'},
        {'status': 'rejected'}, // not counted in any of the 3 buckets
        {}, // missing → pending
      ]);
      expect(c.pending, 3);
      expect(c.processing, 1);
      expect(c.completed, 1);
      expect(c.total, 6);
    });

    test('empty list → zero counts', () {
      final c = GdprStatusCounts.from(const []);
      expect(c.pending, 0);
      expect(c.processing, 0);
      expect(c.completed, 0);
      expect(c.total, 0);
    });
  });

  group('formatTimeAgo', () {
    DateTime clock() => DateTime(2026, 5, 28, 12, 0, 0);

    test('< 1 minute → "just now"', () {
      expect(
          formatTimeAgo(DateTime(2026, 5, 28, 11, 59, 30), now: clock),
          'just now');
    });

    test('minutes < 60 → "Xm ago"', () {
      expect(formatTimeAgo(DateTime(2026, 5, 28, 11, 55), now: clock),
          '5m ago');
    });

    test('hours < 24 → "Xh ago"', () {
      expect(formatTimeAgo(DateTime(2026, 5, 28, 9, 0), now: clock),
          '3h ago');
    });

    test('days → "Xd ago"', () {
      expect(formatTimeAgo(DateTime(2026, 5, 25, 12, 0), now: clock),
          '3d ago');
    });

    test('future timestamps collapse to "just now" (defensive)', () {
      expect(formatTimeAgo(DateTime(2026, 6, 1), now: clock), 'just now');
    });
  });

  group('buildUserExportData', () {
    late FakeFirebaseFirestore db;

    setUp(() async {
      db = FakeFirebaseFirestore();
      // The user to be exported.
      await db.collection('users').doc('u1').set({
        'name': 'Pat',
        'email': 'pat@example.com',
      });

      // Subcollections under users/u1
      await db.collection('users').doc('u1').collection('following')
          .doc('u2').set({'followedAt': Timestamp.now()});
      await db.collection('users').doc('u1').collection('followers')
          .doc('u3').set({'followedAt': Timestamp.now()});
      await db.collection('users').doc('u1').collection('blocked')
          .doc('u4').set({'blockedAt': Timestamp.now()});
      await db.collection('users').doc('u1').collection('trips')
          .doc('t1').set({'destination': 'JFK', 'startDate': Timestamp.now()});

      // Posts authored by u1 + one by someone else (must NOT be exported)
      await db.collection('posts').doc('p1').set({
        'authorId': 'u1', 'caption': 'hello'
      });
      await db.collection('posts').doc('p2').set({
        'authorId': 'u1', 'caption': 'world'
      });
      await db.collection('posts').doc('p3').set({
        'authorId': 'u2', 'caption': 'not me'
      });

      // SafeChecks
      await db.collection('safeChecks').doc('sc1').set({
        'userId': 'u1', 'status': 'safe'
      });

      // Matches — both sides
      await db.collection('matches').doc('m1').set({
        'userA': 'u1', 'userB': 'u9', 'status': 'matched'
      });
      await db.collection('matches').doc('m2').set({
        'userA': 'u8', 'userB': 'u1', 'status': 'pending'
      });
      await db.collection('matches').doc('m3').set({
        'userA': 'u7', 'userB': 'u6', 'status': 'matched'
      }); // unrelated — must not appear

      // Reports filed BY u1
      await db.collection('reports').doc('r1').set({
        'reporterId': 'u1', 'reason': 'spam'
      });

      // Audit log targeting u1
      await db.collection('audit_log').doc('a1').set({
        'targetId': 'u1', 'action': 'verify', 'admin': 'admin@x'
      });
    });

    test('collects every category for the target user', () async {
      final out = await buildUserExportData(db, 'u1',
          now: () => DateTime(2026, 5, 28, 12, 0, 0));

      expect(out['userId'], 'u1');
      expect(out['exportGeneratedAt'], '2026-05-28T12:00:00.000');

      // Profile
      expect((out['user'] as Map?)?['name'], 'Pat');

      // Subcollections
      expect((out['following'] as List).map((e) => e['id']), ['u2']);
      expect((out['followers'] as List).map((e) => e['id']), ['u3']);
      expect((out['blocked'] as List).map((e) => e['id']), ['u4']);
      expect((out['trips'] as List).map((e) => e['id']), ['t1']);

      // Posts — only u1's
      final postIds = (out['posts'] as List).map((e) => e['id']).toSet();
      expect(postIds, {'p1', 'p2'});

      // SafeChecks
      expect((out['safeChecks'] as List).map((e) => e['id']), ['sc1']);

      // Matches — both sides, never the unrelated one
      final matchIds = (out['matches'] as List).map((e) => e['id']).toSet();
      expect(matchIds, {'m1', 'm2'});

      // Reports filed
      expect((out['reportsFiled'] as List).map((e) => e['id']), ['r1']);

      // Audit entries
      expect((out['auditEntriesAboutMe'] as List).map((e) => e['id']),
          ['a1']);
    });

    test('result is jsonEncode-able after normaliseForJson', () async {
      final out = await buildUserExportData(db, 'u1');
      // If any nested Timestamp leaked through normaliseForJson would
      // throw inside jsonEncode — this assertion guards the GDPR
      // export pipeline end-to-end.
      final json = jsonEncode(normaliseForJson(out));
      expect(json, contains('"userId":"u1"'));
      expect(json, contains('p1'));
    });

    test('missing user doc still produces a well-shaped export', () async {
      final out = await buildUserExportData(db, 'ghost');
      // The user key is null but the other top-level keys are present
      // and empty — admin can still upload the file rather than getting
      // a 500 mid-compile.
      expect(out['userId'], 'ghost');
      expect(out['user'], isNull);
      expect(out['posts'], isEmpty);
      expect(out['matches'], isEmpty);
      expect(out['following'], isEmpty);
    });
  });
}
