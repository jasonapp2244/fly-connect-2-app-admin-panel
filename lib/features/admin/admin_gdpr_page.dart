import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/constants/app_colors.dart';
import 'admin_audit_helper.dart';

class AdminGdprPage extends StatefulWidget {
  const AdminGdprPage({super.key});

  @override
  State<AdminGdprPage> createState() => _AdminGdprPageState();
}

class _AdminGdprPageState extends State<AdminGdprPage> {
  List<Map<String, dynamic>> _requests = [];
  String _filter = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _loading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('gdpr_requests')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      if (!mounted) return;
      setState(() {
        _requests = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      debugPrint('[AdminGdpr] fetch failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    switch (_filter) {
      case 'export':
        return _requests.where((r) => r['requestType'] == 'export').toList();
      case 'delete':
        return _requests.where((r) => r['requestType'] == 'delete').toList();
      case 'pending':
        return _requests.where((r) => r['status'] == 'pending').toList();
      case 'completed':
        return _requests.where((r) => r['status'] == 'completed').toList();
      default:
        return _requests;
    }
  }

  int get _pendingCount =>
      _requests.where((r) => r['status'] == 'pending').length;
  int get _processingCount =>
      _requests.where((r) => r['status'] == 'processing').length;
  int get _completedCount =>
      _requests.where((r) => r['status'] == 'completed').length;

  Future<void> _process(String id) async {
    await FirebaseFirestore.instance
        .collection('gdpr_requests')
        .doc(id)
        .update({'status': 'processing'});
    await logAdminAction(
      action: 'process_gdpr',
      targetType: 'gdpr_request',
      targetId: id,
      details: 'Started processing GDPR request $id',
    );
    _fetchRequests();
  }

  Future<void> _complete(String id) async {
    await FirebaseFirestore.instance
        .collection('gdpr_requests')
        .doc(id)
        .update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    await logAdminAction(
      action: 'complete_gdpr',
      targetType: 'gdpr_request',
      targetId: id,
      details: 'Completed GDPR request $id',
    );
    _fetchRequests();
  }

  /// Compile the user's data into a single JSON file, upload to Storage,
  /// and attach the download URL to the gdpr_requests doc so the admin
  /// can email it. This is the actual "right to access" delivery — until
  /// now the admin was only flipping a status flag.
  ///
  /// Runs client-side from the admin browser; for large user accounts
  /// this should eventually move to a Cloud Function (background job
  /// with auth + a 9-minute timeout). Acceptable for MVP.
  Future<void> _compileExport(Map<String, dynamic> req) async {
    final messenger = ScaffoldMessenger.of(context);
    final docId = (req['docId'] ?? req['id']) as String? ?? '';
    if (docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Request has no id — cannot compile.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final userId = (req['userId'] as String?) ?? '';
    if (userId.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Request has no userId — cannot compile.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    messenger.showSnackBar(const SnackBar(
      content: Text('Compiling user data export…'),
      duration: Duration(seconds: 2),
    ));
    try {
      final db = FirebaseFirestore.instance;
      final export = <String, dynamic>{
        'exportGeneratedAt': DateTime.now().toIso8601String(),
        'userId': userId,
      };

      // 1. Top-level user doc
      final userDoc = await db.collection('users').doc(userId).get();
      export['user'] = userDoc.data();

      // 2. Subcollections under the user doc
      for (final sub in ['following', 'followers', 'blocked', 'trips']) {
        final snap = await db.collection('users').doc(userId)
            .collection(sub).get();
        export[sub] = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }

      // 3. Posts authored by this user
      final postsSnap = await db.collection('posts')
          .where('authorId', isEqualTo: userId).limit(500).get();
      export['posts'] = postsSnap.docs
          .map((d) => {'id': d.id, ...d.data()}).toList();

      // 4. SafeCheck history
      final scSnap = await db.collection('safeChecks')
          .where('userId', isEqualTo: userId).limit(500).get();
      export['safeChecks'] = scSnap.docs
          .map((d) => {'id': d.id, ...d.data()}).toList();

      // 5. Matches involving this user
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
      export['reportsFiled'] = reportsSnap.docs
          .map((d) => {'id': d.id, ...d.data()}).toList();

      // 7. Audit actions affecting this user
      final auditSnap = await db.collection('audit_log')
          .where('targetId', isEqualTo: userId).limit(500).get();
      export['auditEntriesAboutMe'] = auditSnap.docs
          .map((d) => {'id': d.id, ...d.data()}).toList();

      // Convert non-JSON-serialisable values (Timestamps, etc.)
      final jsonText = const JsonEncoder.withIndent('  ')
          .convert(_normaliseForJson(export));

      // Upload to Storage at gdpr_exports/{userId}/{docId}.json
      final ref = FirebaseStorage.instance.ref(
          'gdpr_exports/$userId/$docId.json');
      await ref.putString(
        jsonText,
        format: PutStringFormat.raw,
        metadata: SettableMetadata(
            contentType: 'application/json',
            customMetadata: {'gdprRequestId': docId}),
      );
      final url = await ref.getDownloadURL();

      // Mark the request completed AND save the download URL on the doc
      await db.collection('gdpr_requests').doc(docId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'exportUrl': url,
        'exportSizeBytes': jsonText.length,
      });
      await logAdminAction(
        action: 'complete_gdpr',
        targetType: 'gdpr_request',
        targetId: docId,
        details:
            'Compiled + uploaded export for user $userId (${jsonText.length} bytes)',
      );
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Export compiled. URL saved on the request.'),
          backgroundColor: Colors.green,
        ));
      }
      _fetchRequests();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  /// Recursively normalise Firestore-native types (Timestamp, GeoPoint,
  /// DocumentReference) into JSON-friendly primitives.
  Object? _normaliseForJson(Object? v) {
    if (v == null || v is num || v is bool || v is String) return v;
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is GeoPoint) return {'lat': v.latitude, 'lng': v.longitude};
    if (v is DocumentReference) return v.path;
    if (v is List) return v.map(_normaliseForJson).toList();
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _normaliseForJson(val)));
    }
    return v.toString();
  }

  Future<void> _reject(String id) async {
    final confirmed = await _showConfirm(
      context,
      title: 'Reject GDPR Request',
      message:
          'Reject this request? The user will be notified. This action is logged.',
      confirmLabel: 'Reject',
      confirmColor: AppColors.error,
    );
    if (!confirmed) return;
    await FirebaseFirestore.instance
        .collection('gdpr_requests')
        .doc(id)
        .update({'status': 'rejected'});
    await logAdminAction(
      action: 'reject_gdpr',
      targetType: 'gdpr_request',
      targetId: id,
      details: 'Rejected GDPR request $id',
    );
    _fetchRequests();
  }

  Future<bool> _showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(message,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    final filtered = _filteredRequests;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'GDPR requests must be processed within 30 days per regulation.',
                    style: TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatCard('Pending', _pendingCount, AppColors.warning),
              const SizedBox(width: 12),
              _buildStatCard('Processing', _processingCount, Colors.blue),
              const SizedBox(width: 12),
              _buildStatCard('Completed', _completedCount, AppColors.online),
              const SizedBox(width: 12),
              _buildStatCard('Total', _requests.length, AppColors.dark),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterPill('All', 'all'),
              _filterPill('Export Requests', 'export'),
              _filterPill('Delete Requests', 'delete'),
              _filterPill('Pending', 'pending'),
              _filterPill('Completed', 'completed'),
            ],
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('No GDPR requests',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...filtered.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRequestCard(r),
                )),
        ],
      ),
    );
  }

  Widget _filterPill(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.dark : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('$count',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final userName = (r['userName'] ?? 'Unknown') as String;
    final userEmail = (r['userEmail'] ?? '') as String;
    final requestType = (r['requestType'] ?? 'export') as String;
    final status = (r['status'] ?? 'pending') as String;
    final createdAt = r['createdAt'];
    String timeText = '';
    if (createdAt is Timestamp) {
      timeText = _timeAgo(createdAt.toDate());
    }
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    final typeColor = requestType == 'delete' ? AppColors.error : Colors.purple;
    final statusColor = status == 'completed'
        ? AppColors.online
        : status == 'processing'
            ? Colors.blue
            : status == 'rejected'
                ? AppColors.error
                : AppColors.warning;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: typeColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.dark,
                          child: Text(initial,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(userName,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text(userEmail,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(requestType.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: typeColor)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(status.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Submitted $timeText',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    if (r['notes'] != null && (r['notes'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(r['notes'] as String,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    if (r['exportUrl'] != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.online.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.online.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline,
                              color: AppColors.online, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Export ready · ${((r['exportSizeBytes'] as int? ?? 0) / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.online),
                            ),
                          ),
                          SelectableText(
                            r['exportUrl'] as String,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace'),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Compile + upload the user's data — only shown for
                        // 'export' requests that haven't been compiled yet.
                        if (r['requestType'] == 'export' &&
                            r['exportUrl'] == null)
                          SizedBox(
                            width: 140,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: () => _compileExport(r),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.dark,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                textStyle: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              child: const Text('Compile Export'),
                            ),
                          ),
                        SizedBox(
                          width: 140,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () => _process(id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.online,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            child: const Text('Approve & Process'),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () => _complete(id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.dark,
                              padding: EdgeInsets.zero,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            child: const Text('Mark Completed'),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          height: 32,
                          child: OutlinedButton(
                            onPressed: () => _reject(id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
