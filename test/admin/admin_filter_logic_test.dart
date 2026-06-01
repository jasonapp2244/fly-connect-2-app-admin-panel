import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyconnect/features/admin/admin_filter_logic.dart';

void main() {
  group('severityFor', () {
    test('> 5 → high, > 2 → medium, else low (boundary inclusive)', () {
      expect(severityFor(0), ReportSeverity.low);
      expect(severityFor(2), ReportSeverity.low);
      expect(severityFor(3), ReportSeverity.medium);
      expect(severityFor(5), ReportSeverity.medium);
      expect(severityFor(6), ReportSeverity.high);
      expect(severityFor(99), ReportSeverity.high);
    });

    test('severityLabel + severityColor are defined for every bucket', () {
      for (final s in ReportSeverity.values) {
        expect(severityLabel(s), isNotEmpty);
        expect(severityColor(s), isA<Color>());
      }
    });
  });

  group('applyReportFilter', () {
    final reports = [
      {'id': 'r1', 'reportCount': 1},
      {'id': 'r2', 'reportCount': 3},
      {'id': 'r3', 'reportCount': 5},
      {'id': 'r4', 'reportCount': 6},
      {'id': 'r5'}, // missing → treated as 0 → low
    ];

    test('high filter keeps only > 5', () {
      expect(applyReportFilter(reports, 'high').map((r) => r['id']), ['r4']);
    });

    test('medium filter keeps 3..5 inclusive', () {
      expect(applyReportFilter(reports, 'medium').map((r) => r['id']),
          ['r2', 'r3']);
    });

    test('low filter keeps <= 2 including missing reportCount', () {
      expect(applyReportFilter(reports, 'low').map((r) => r['id']),
          ['r1', 'r5']);
    });

    test('unknown filter → pass-through copy', () {
      final out = applyReportFilter(reports, 'all');
      expect(out.length, 5);
      // Independent copy — mutating doesn't poison the input.
      out.clear();
      expect(reports.length, 5);
    });
  });

  group('ReportSeverityCounts.from', () {
    test('correctly buckets a mixed list', () {
      final c = ReportSeverityCounts.from([
        {'reportCount': 8},
        {'reportCount': 7},
        {'reportCount': 4},
        {'reportCount': 1},
        {'reportCount': 0},
        {},
      ]);
      expect(c.total, 6);
      expect(c.high, 2);
      expect(c.medium, 1);
      expect(c.low, 3);
    });
  });

  group('applyUsersFilter', () {
    final users = [
      {'uid': 'u1', 'name': 'Alex', 'email': 'a@x.com',
       'isVerified': true, 'role': 'user'},
      {'uid': 'u2', 'name': 'Pat', 'email': 'pat@x.com',
       'isVerified': false, 'role': 'user'},
      {'uid': 'u3', 'name': 'Bizco', 'email': 'biz@x.com',
       'isVerified': true, 'role': 'business'},
      {'uid': 'u4', 'name': 'Banner', 'email': 'b@x.com',
       'isBanned': true, 'role': 'user'},
      {'uid': 'u5', 'name': 'Admin Joe', 'email': 'a2@x.com',
       'role': 'admin'},
    ];

    test('no search + filter=all → identical copy', () {
      final out = applyUsersFilter(users);
      expect(out.length, 5);
      out.clear();
      expect(users.length, 5);
    });

    test('search is case-insensitive and matches name OR email', () {
      expect(applyUsersFilter(users, search: 'alex').map((u) => u['uid']),
          ['u1']);
      expect(applyUsersFilter(users, search: 'BIZ').map((u) => u['uid']),
          ['u3']); // matches both name "Bizco" and email "biz@x.com"
      expect(applyUsersFilter(users, search: 'admin').map((u) => u['uid']),
          ['u5']);
    });

    test('filter=verified keeps only isVerified == true', () {
      expect(applyUsersFilter(users, filter: 'verified')
          .map((u) => u['uid']),
          ['u1', 'u3']);
    });

    test('filter=unverified excludes verified', () {
      expect(applyUsersFilter(users, filter: 'unverified')
          .map((u) => u['uid'])
          .toSet(),
          {'u2', 'u4', 'u5'});
    });

    test('filter=banned + filter=business + filter=admin', () {
      expect(applyUsersFilter(users, filter: 'banned')
          .map((u) => u['uid']),
          ['u4']);
      expect(applyUsersFilter(users, filter: 'business')
          .map((u) => u['uid']),
          ['u3']);
      expect(applyUsersFilter(users, filter: 'admin')
          .map((u) => u['uid']),
          ['u5']);
    });

    test('search + filter combine (intersection, not union)', () {
      final out = applyUsersFilter(users,
          search: 'biz', filter: 'verified');
      expect(out.map((u) => u['uid']), ['u3']);
    });
  });

  group('UserCounts.from', () {
    test('counts verified/unverified/banned/business correctly', () {
      final c = UserCounts.from([
        {'isVerified': true, 'role': 'user'},
        {'isVerified': true, 'role': 'business'},
        {'isVerified': false},
        {'isBanned': true},
        {},
      ]);
      expect(c.total, 5);
      expect(c.verified, 2);
      expect(c.unverified, 3); // anything not explicitly true → unverified
      expect(c.banned, 1);
      expect(c.business, 1);
    });
  });
}
