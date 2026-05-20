import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import 'admin_audit_helper.dart';

class AdminSafeCheckPage extends StatefulWidget {
  const AdminSafeCheckPage({super.key});

  @override
  State<AdminSafeCheckPage> createState() => _AdminSafeCheckPageState();
}

class _AdminSafeCheckPageState extends State<AdminSafeCheckPage> {
  List<Map<String, dynamic>> _checkIns = [];
  bool _loading = true;
  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseFirestore.instance
        .collection('safeChecks')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _checkIns = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _loading = false;
      });
    }, onError: (e) {
      debugPrint('[AdminSafeCheck] stream error: $e');
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'safe':
        return AppColors.online;
      case 'unsure':
        return AppColors.warning;
      case 'need_help':
        return AppColors.error;
      case 'escalated':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'safe':
        return 'Safe';
      case 'unsure':
        return 'Unsure';
      case 'need_help':
        return 'Need Help';
      case 'escalated':
        return 'Escalated';
      default:
        return status;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  int get _activeCount {
    final now = DateTime.now();
    return _checkIns.where((c) {
      final expires = c['expiresAt'];
      if (expires == null) return false;
      final expiresAt = (expires as Timestamp).toDate();
      return expiresAt.isAfter(now);
    }).length;
  }

  int _countByStatus(String status) =>
      _checkIns.where((c) => c['status'] == status).length;

  Future<void> _resolveCheckIn(String docId) async {
    await FirebaseFirestore.instance
        .collection('safeChecks')
        .doc(docId)
        .update({'expiresAt': Timestamp.fromDate(DateTime.now())});
    await logAdminAction(
      action: 'resolve_safecheck',
      targetType: 'safecheck',
      targetId: docId,
      details: 'Marked check-in $docId as resolved',
    );
  }

  Future<void> _escalateCheckIn(String docId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Escalate to Emergency',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
            'Escalate $userName\'s check-in to emergency status? This will flag it for immediate response.',
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
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('safeChecks')
        .doc(docId)
        .update({
      'status': 'escalated',
      'escalatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userName\'s check-in escalated to emergency'),
          backgroundColor: Colors.purple,
        ),
      );
    }
  }

  Future<void> _sendAdminMessage(
      String docId, String userName, String userId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Message $userName',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Type your message...',
            hintStyle: const TextStyle(color: AppColors.textHint),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.inputBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.inputBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.dark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result == null || result.isEmpty) return;

    // Create a notification for the user
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'uid': userId,
      'title': 'Admin SafeCheck Message',
      'body': result,
      'type': 'admin_safecheck',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message sent to $userName'),
          backgroundColor: AppColors.online,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.expand(
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final needHelpCount = _countByStatus('need_help');
    final escalatedCount = _countByStatus('escalated');
    final needHelpItems = _checkIns
        .where((c) =>
            c['status'] == 'need_help' || c['status'] == 'escalated')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alert banner
          if (needHelpCount > 0 || escalatedCount > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [
                        if (needHelpCount > 0)
                          '$needHelpCount user${needHelpCount == 1 ? '' : 's'} need help',
                        if (escalatedCount > 0)
                          '$escalatedCount escalated',
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Stats row
          Row(
            children: [
              _buildStatCard('Active Check-ins', _activeCount, Colors.blue),
              const SizedBox(width: 12),
              _buildStatCard('Safe', _countByStatus('safe'), AppColors.online),
              const SizedBox(width: 12),
              _buildStatCard(
                  'Unsure', _countByStatus('unsure'), AppColors.warning),
              const SizedBox(width: 12),
              _buildStatCard(
                  'Need Help', needHelpCount, AppColors.error),
              const SizedBox(width: 12),
              _buildStatCard('Escalated', escalatedCount, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          // Live Feed
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Live Check-in Feed',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._checkIns.map((c) => _buildFeedRow(c)),
                if (_checkIns.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('No check-ins yet',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Priority: Need Help / Escalated Queue
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Priority Queue — Need Help & Escalated',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: needHelpItems.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'No users currently need help',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14),
                            ),
                          ),
                        )
                      : Column(
                          children: needHelpItems
                              .map((c) => _buildNeedHelpCard(c))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
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
                  Text(
                    '$count',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedRow(Map<String, dynamic> checkIn) {
    final status = checkIn['status'] ?? '';
    final isUrgent = status == 'need_help' || status == 'escalated';
    final createdAt = checkIn['createdAt'] != null
        ? (checkIn['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isUrgent ? AppColors.error.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isUrgent ? AppColors.error : Colors.transparent,
            width: isUrgent ? 3 : 0,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _statusColor(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.backgroundGrey,
            child: Text(
              (checkIn['userName'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      checkIn['userName'] ?? 'Unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                            color: _statusColor(status),
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (checkIn['message'] != null &&
                    (checkIn['message'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      checkIn['message'],
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (checkIn['city'] != null)
                Text(checkIn['city'],
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              Text(_timeAgo(createdAt),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          // Inline Resolve button removed — Priority Queue section below has Resolve action.
        ],
      ),
    );
  }

  Widget _buildNeedHelpCard(Map<String, dynamic> checkIn) {
    final createdAt = checkIn['createdAt'] != null
        ? (checkIn['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final status = checkIn['status'] ?? 'need_help';
    final isEscalated = status == 'escalated';
    final statusColor = _statusColor(status);
    final userName = checkIn['userName'] ?? 'Unknown';
    final userId = checkIn['userId'] ?? checkIn['uid'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: statusColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: statusColor.withValues(alpha: 0.1),
                child: Text(
                  userName[0].toUpperCase(),
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        if (isEscalated)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Escalated',
                                style: TextStyle(
                                    color: Colors.purple,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    if (checkIn['email'] != null)
                      Text(checkIn['email'],
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (checkIn['city'] != null)
                    Text(checkIn['city'],
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  Text(_timeAgo(createdAt),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
          if (checkIn['message'] != null &&
              (checkIn['message'] as String).isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              checkIn['message'],
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    _sendAdminMessage(checkIn['id'], userName, userId),
                icon: const Icon(Icons.message_outlined, size: 14),
                label: const Text('Message'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              if (!isEscalated)
                ElevatedButton.icon(
                  onPressed: () =>
                      _escalateCheckIn(checkIn['id'], userName),
                  icon: const Icon(Icons.priority_high, size: 14),
                  label: const Text('Escalate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              if (!isEscalated) const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _resolveCheckIn(checkIn['id']),
                icon: const Icon(Icons.check_circle_outline, size: 14),
                label: const Text('Resolve'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.online,
                  side: const BorderSide(color: AppColors.online),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
