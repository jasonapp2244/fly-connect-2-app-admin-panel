import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Writes a single entry to `audit_log` Firestore collection.
///
/// Every admin action that mutates Firestore should call this so the
/// Audit Log page has a full history.
///
/// `action`     — short verb identifier (e.g. `ban_user`, `approve_event`,
///                `reject_promotion`, `resolve_report`, `verify_business`).
/// `targetType` — what was acted on (`user`, `post`, `event`, `promotion`,
///                `report`, `gdpr_request`, `business`, `safecheck`).
/// `targetId`   — Firestore doc id of the target (or empty string).
/// `details`    — human-readable one-liner summarising the change.
///
/// Failure to write is non-fatal — logged via [debugPrint].
Future<void> logAdminAction({
  required String action,
  required String targetType,
  required String targetId,
  required String details,
}) async {
  try {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    await FirebaseFirestore.instance.collection('audit_log').add({
      'adminId': user?.uid ?? 'unknown',
      'adminName': user?.displayName ?? user?.email ?? 'Unknown Admin',
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    debugPrint('[AuditLog] write failed: $e');
  }
}
