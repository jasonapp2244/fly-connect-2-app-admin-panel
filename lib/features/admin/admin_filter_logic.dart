import 'package:flutter/material.dart';

/// Shared pure-logic helpers for the admin Content + Users pages.
///
/// Each page used to have its own private `_filtered…` getter plus a
/// fistful of `_xxxCount` getters that all did the same shape of work
/// (filter / sort / count a List<Map<String, dynamic>>). Pulled out so:
///   • the rules become testable without mounting the page
///   • severity / role thresholds live in one place per concept
///   • adding a new filter is touching one file, not n
///
/// These helpers do NO Firestore I/O — they operate on the already-fetched
/// list of doc maps. Firestore-shaped tests still go through
/// `fake_cloud_firestore` against the page's `_fetchXxx`.

// ── Content page (reported posts) ───────────────────────────────────

/// Severity buckets for a reported post, keyed off the `reportCount`
/// field on the Firestore doc.
enum ReportSeverity { high, medium, low }

/// Threshold rule: > 5 reports is high, > 2 is medium, else low.
/// Centralised here because the page uses the same rule in 3 places
/// (filter, count, label/colour).
ReportSeverity severityFor(int reportCount) {
  if (reportCount > 5) return ReportSeverity.high;
  if (reportCount > 2) return ReportSeverity.medium;
  return ReportSeverity.low;
}

String severityLabel(ReportSeverity s) {
  switch (s) {
    case ReportSeverity.high: return 'High';
    case ReportSeverity.medium: return 'Medium';
    case ReportSeverity.low: return 'Low';
  }
}

Color severityColor(ReportSeverity s) {
  switch (s) {
    case ReportSeverity.high: return const Color(0xFFFF3B30);
    case ReportSeverity.medium: return const Color(0xFFFF9500);
    case ReportSeverity.low: return const Color(0xFF8A8D9A);
  }
}

/// Filter the reported-posts list. Pass-through for `'all'` / unknown.
List<Map<String, dynamic>> applyReportFilter(
    List<Map<String, dynamic>> reports, String filter) {
  switch (filter) {
    case 'high':
      return reports
          .where((r) => severityFor(_reportCount(r)) == ReportSeverity.high)
          .toList();
    case 'medium':
      return reports
          .where((r) =>
              severityFor(_reportCount(r)) == ReportSeverity.medium)
          .toList();
    case 'low':
      return reports
          .where((r) => severityFor(_reportCount(r)) == ReportSeverity.low)
          .toList();
    default:
      return List<Map<String, dynamic>>.from(reports);
  }
}

class ReportSeverityCounts {
  final int total;
  final int high;
  final int medium;
  final int low;

  const ReportSeverityCounts({
    required this.total,
    required this.high,
    required this.medium,
    required this.low,
  });

  factory ReportSeverityCounts.from(List<Map<String, dynamic>> reports) {
    int h = 0, m = 0, l = 0;
    for (final r in reports) {
      switch (severityFor(_reportCount(r))) {
        case ReportSeverity.high: h++; break;
        case ReportSeverity.medium: m++; break;
        case ReportSeverity.low: l++; break;
      }
    }
    return ReportSeverityCounts(
        total: reports.length, high: h, medium: m, low: l);
  }
}

int _reportCount(Map<String, dynamic> r) {
  final raw = r['reportCount'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return 0;
}

// ── Users page ──────────────────────────────────────────────────────

/// Filter + search the admin users list. Empty `search` is a no-op;
/// unknown `filter` falls through to "all".
List<Map<String, dynamic>> applyUsersFilter(
  List<Map<String, dynamic>> users, {
  String search = '',
  String filter = 'all',
}) {
  var list = List<Map<String, dynamic>>.from(users);

  if (search.isNotEmpty) {
    final q = search.toLowerCase();
    list = list.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  switch (filter) {
    case 'verified':
      return list.where((u) => u['isVerified'] == true).toList();
    case 'unverified':
      return list.where((u) => u['isVerified'] != true).toList();
    case 'banned':
      return list.where((u) => u['isBanned'] == true).toList();
    case 'business':
      return list.where((u) => u['role'] == 'business').toList();
    case 'admin':
      return list.where((u) => u['role'] == 'admin').toList();
    default:
      return list;
  }
}

class UserCounts {
  final int total;
  final int verified;
  final int unverified;
  final int banned;
  final int business;

  const UserCounts({
    required this.total,
    required this.verified,
    required this.unverified,
    required this.banned,
    required this.business,
  });

  factory UserCounts.from(List<Map<String, dynamic>> users) {
    int v = 0, u = 0, b = 0, biz = 0;
    for (final user in users) {
      if (user['isVerified'] == true) {
        v++;
      } else {
        u++;
      }
      if (user['isBanned'] == true) b++;
      if (user['role'] == 'business') biz++;
    }
    return UserCounts(
      total: users.length,
      verified: v,
      unverified: u,
      banned: b,
      business: biz,
    );
  }
}
