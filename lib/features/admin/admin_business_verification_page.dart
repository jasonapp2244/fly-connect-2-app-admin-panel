import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import 'admin_audit_helper.dart';

class AdminBusinessVerificationPage extends StatefulWidget {
  const AdminBusinessVerificationPage({super.key});

  @override
  State<AdminBusinessVerificationPage> createState() =>
      _AdminBusinessVerificationPageState();
}

class _AdminBusinessVerificationPageState
    extends State<AdminBusinessVerificationPage> {
  List<Map<String, dynamic>> _businesses = [];
  String _filter = 'all';
  bool _loading = true;
  static const int _pageSize = 50;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchBusinesses();
  }

  Future<void> _fetchBusinesses() async {
    setState(() { _loading = true; _lastDoc = null; _hasMore = true; });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'business')
          .limit(_pageSize)
          .get();
      if (!mounted) return;
      setState(() {
        _businesses = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _pageSize;
      });
    } catch (e) {
      debugPrint('[AdminBusinessVerify] fetch failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchMore() async {
    if (_lastDoc == null || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'business')
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();
      if (!mounted) return;
      final newDocs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      setState(() {
        _businesses.addAll(newDocs);
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;
        _hasMore = snapshot.docs.length == _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('[AdminBusinessVerify] fetchMore failed: $e');
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<Map<String, dynamic>> get _filteredBusinesses {
    switch (_filter) {
      case 'pending':
        return _businesses
            .where((b) => (b['verificationStatus'] ?? 'none') == 'pending')
            .toList();
      case 'verified':
        return _businesses
            .where((b) => b['verificationStatus'] == 'verified')
            .toList();
      case 'rejected':
        return _businesses
            .where((b) => b['verificationStatus'] == 'rejected')
            .toList();
      default:
        return _businesses;
    }
  }

  int get _pendingCount => _businesses
      .where((b) => (b['verificationStatus'] ?? 'none') == 'pending')
      .length;
  int get _verifiedCount => _businesses
      .where((b) => b['verificationStatus'] == 'verified')
      .length;
  int get _rejectedCount => _businesses
      .where((b) => b['verificationStatus'] == 'rejected')
      .length;

  Future<void> _approve(String id) async {
    await FirebaseFirestore.instance.collection('users').doc(id).update({
      'verificationStatus': 'verified',
      'isVerified': true,
    });
    await logAdminAction(
      action: 'verify_business',
      targetType: 'business',
      targetId: id,
      details: 'Verified business $id',
    );
    _fetchBusinesses();
  }

  Future<void> _reject(String id, String name) async {
    final confirmed = await _showConfirm(
      context,
      title: 'Reject Verification',
      message:
          'Reject verification for "$name"? They will be notified and can resubmit documents.',
      confirmLabel: 'Reject',
      confirmColor: AppColors.error,
    );
    if (!confirmed) return;
    await FirebaseFirestore.instance.collection('users').doc(id).update({
      'verificationStatus': 'rejected',
      'isVerified': false,
    });
    await logAdminAction(
      action: 'reject_business_verification',
      targetType: 'business',
      targetId: id,
      details: 'Rejected verification for "$name"',
    );
    _fetchBusinesses();
  }

  Future<void> _requestMoreInfo(String id, String name) async {
    final noteCtrl = TextEditingController(text: 'Please upload additional verification documents.');
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Request More Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Send a request to "$name" for additional information.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Note to business...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Send Request')),
        ],
      ),
    );
    if (submitted != true) return;
    await FirebaseFirestore.instance.collection('users').doc(id).update({
      'verificationStatus': 'info_requested',
      'verificationNote': noteCtrl.text.trim(),
    });
    // Send notification to the business user
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': id,
      'type': 'verification',
      'title': 'More info needed',
      'body': noteCtrl.text.trim(),
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await logAdminAction(
      action: 'request_more_info',
      targetType: 'business',
      targetId: id,
      details: 'Requested more info from "$name": ${noteCtrl.text.trim()}',
    );
    _fetchBusinesses();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    final filtered = _filteredBusinesses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatCard(
                  'Pending Verification', _pendingCount, AppColors.warning),
              const SizedBox(width: 12),
              _buildStatCard('Verified', _verifiedCount, AppColors.online),
              const SizedBox(width: 12),
              _buildStatCard('Rejected', _rejectedCount, AppColors.error),
              const SizedBox(width: 12),
              _buildStatCard(
                  'Total Businesses', _businesses.length, Colors.blue),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _filterPill('All', 'all'),
              const SizedBox(width: 8),
              _filterPill('Pending', 'pending'),
              const SizedBox(width: 8),
              _filterPill('Verified', 'verified'),
              const SizedBox(width: 8),
              _filterPill('Rejected', 'rejected'),
              const Spacer(),
              IconButton(
                onPressed: _fetchBusinesses,
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.textSecondary,
              ),
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
                child: Text('No businesses found',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...filtered.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildBusinessCard(b),
                )),
          const SizedBox(height: 16),
          if (_hasMore)
            Center(child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _loadingMore ? null : _fetchMore,
                icon: _loadingMore
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.expand_more, size: 16),
                label: Text(_loadingMore ? 'Loading...' : 'Load more',
                    style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dark, foregroundColor: Colors.white,
                  elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
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
                      textAlign: TextAlign.center,
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

  Widget _buildBusinessCard(Map<String, dynamic> b) {
    final id = b['id'] as String;
    final name = (b['name'] ?? b['businessName'] ?? 'Unnamed') as String;
    final email = (b['email'] ?? '') as String;
    final ein = (b['ein'] ?? '') as String;
    final licenseNumber = (b['licenseNumber'] ?? '') as String;
    final status = (b['verificationStatus'] ?? 'none') as String;
    final docs = (b['verificationDocs'] as List?) ?? [];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final statusColor = status == 'verified'
        ? AppColors.online
        : status == 'rejected'
            ? AppColors.error
            : status == 'pending'
                ? AppColors.warning
                : AppColors.textSecondary;

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
            Container(width: 4, color: statusColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.dark,
                          child: Text(initial,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              if (email.isNotEmpty)
                                Text(email,
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        if (ein.isNotEmpty)
                          _infoRow(Icons.numbers, 'EIN: $ein'),
                        if (licenseNumber.isNotEmpty)
                          _infoRow(
                              Icons.badge_outlined, 'License: $licenseNumber'),
                        GestureDetector(
                          onTap: docs.isNotEmpty ? () => _showDocuments(docs, name) : null,
                          child: _infoRow(
                            docs.isNotEmpty ? Icons.folder_open : Icons.folder_outlined,
                            '${docs.length} document${docs.length == 1 ? '' : 's'}${docs.isNotEmpty ? ' (tap to view)' : ''}'),
                        ),
                      ],
                    ),
                    if (docs.isEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 16, color: AppColors.warning),
                            SizedBox(width: 8),
                            Text('No documents submitted',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 90,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () => _approve(id),
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
                            child: const Text('Approve'),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          height: 32,
                          child: OutlinedButton(
                            onPressed: () => _reject(id, name),
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
                        SizedBox(
                          width: 140,
                          height: 32,
                          child: OutlinedButton(
                            onPressed: () => _requestMoreInfo(id, name),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warning,
                              side: const BorderSide(color: AppColors.warning),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            child: const Text('Request More Info'),
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

  void _showDocuments(List docs, String businessName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Documents — $businessName',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ...docs.asMap().entries.map((entry) {
              final url = entry.value.toString();
              return ListTile(
                leading: const Icon(Icons.description_outlined, color: AppColors.dark),
                title: Text('Document ${entry.key + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: SelectableText(url,
                  style: const TextStyle(fontSize: 11, color: Colors.blue)),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18, color: Colors.blue),
                  onPressed: () async {
                    final uri = Uri.tryParse(url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              );
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
