import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';

class AdminContentPage extends StatefulWidget {
  const AdminContentPage({super.key});

  @override
  State<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends State<AdminContentPage> {
  List<Map<String, dynamic>> _reports = [];
  String _filter = 'all';
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _loading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('isReported', isEqualTo: true)
          .orderBy('reportCount', descending: true)
          .limit(50)
          .get();
      setState(() {
        _reports = snapshot.docs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id;
          return data;
        }).toList();
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[AdminContent] Failed to load reported posts: $e\n$st');
      if (mounted) setState(() { _loading = false; _loadError = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    switch (_filter) {
      case 'high':
        return _reports.where((r) => (r['reportCount'] ?? 0) > 5).toList();
      case 'medium':
        return _reports
            .where((r) =>
                (r['reportCount'] ?? 0) > 2 && (r['reportCount'] ?? 0) <= 5)
            .toList();
      case 'low':
        return _reports.where((r) => (r['reportCount'] ?? 0) <= 2).toList();
      default:
        return _reports;
    }
  }

  int get _pendingCount => _reports.length;
  int get _highCount => _reports.where((r) => (r['reportCount'] ?? 0) > 5).length;
  int get _mediumCount =>
      _reports.where((r) =>
          (r['reportCount'] ?? 0) > 2 && (r['reportCount'] ?? 0) <= 5).length;

  String _severityLabel(int reportCount) {
    if (reportCount > 5) return 'High';
    if (reportCount > 2) return 'Medium';
    return 'Low';
  }

  Color _severityColor(int reportCount) {
    if (reportCount > 5) return const Color(0xFFFF3B30);
    if (reportCount > 2) return const Color(0xFFFF9500);
    return const Color(0xFF8A8D9A);
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
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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

  Future<void> _approvePost(Map<String, dynamic> report) async {
    final docId = report['docId'] as String;
    await FirebaseFirestore.instance.collection('posts').doc(docId).update({
      'isReported': false,
      'reportCount': 0,
    });
    await _fetchReports();
  }

  Future<void> _removePost(Map<String, dynamic> report) async {
    final docId = report['docId'] as String;
    final authorName = report['authorName'] ?? 'this user';

    final confirmed = await _showConfirm(
      context,
      title: 'Remove Post',
      message:
          'Permanently delete this post by $authorName? This cannot be undone.',
      confirmLabel: 'Remove',
      confirmColor: AppColors.error,
    );
    if (!confirmed) return;

    await FirebaseFirestore.instance.collection('posts').doc(docId).delete();
    await _fetchReports();
  }

  Future<void> _banUser(Map<String, dynamic> report) async {
    final userId = report['authorId'] as String? ?? report['userId'] as String?;
    final authorName = report['authorName'] ?? 'this user';
    if (userId == null) return;

    final confirmed = await _showConfirm(
      context,
      title: 'Ban User',
      message:
          'Ban $authorName from using FlyConnect? They will not be able to log in.',
      confirmLabel: 'Ban User',
      confirmColor: AppColors.dark,
    );
    if (!confirmed) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'isBanned': true});
    await _fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReports;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Failed to load reports', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(_loadError!, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: _fetchReports, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ]))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 20),
                    _buildFilterTabs(),
                    const SizedBox(height: 20),
                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'No reported content',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ...filtered.map((report) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildReportCard(report),
                          )),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    final stats = [
      {
        'label': 'Pending Review',
        'count': _pendingCount,
        'color': const Color(0xFFFF9500),
      },
      {
        'label': 'High Severity',
        'count': _highCount,
        'color': const Color(0xFFFF3B30),
      },
      {
        'label': 'Medium Severity',
        'count': _mediumCount,
        'color': const Color(0xFFFF9500),
      },
      {
        'label': 'Low Severity',
        'count': _pendingCount - _highCount - _mediumCount,
        'color': const Color(0xFF8A8D9A),
      },
    ];

    return Row(
      children: stats.map((s) {
        final color = s['color'] as Color;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Container(width: 4, height: 72, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s['count']}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s['label'] as String,
                          style: const TextStyle(
                            color: Color(0xFF8A8D9A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilterTabs() {
    final tabs = {
      'all': 'All Reports',
      'high': 'High Severity',
      'medium': 'Medium',
      'low': 'Low',
    };

    return Row(
      children: [
        ...tabs.entries.map((entry) {
          final isActive = _filter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = entry.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF1A1D27)
                      : const Color(0xFFF0F0F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF8A8D9A),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        IconButton(
          onPressed: _fetchReports,
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.textSecondary,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final reportCount = (report['reportCount'] ?? 0) as int;
    final accentColor = _severityColor(reportCount);
    final severityLabel = _severityLabel(reportCount);
    final authorName =
        report['authorName'] ?? report['userName'] ?? 'Unknown';
    final caption = report['caption'] ?? report['content'] ?? '';
    final truncatedCaption =
        caption.length > 80 ? '${caption.substring(0, 80)}...' : caption;
    final reason = report['reportReason'] ?? 'Reported by users';
    final initial = authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';
    final timestamp = report['createdAt'];
    String timeText = '';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      timeText =
          '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent bar
          Container(width: 4, color: accentColor),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF1A1D27),
                        child: Text(initial,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Post',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF8A8D9A))),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          severityLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Report count + reason + time
                  Row(
                    children: [
                      Icon(Icons.flag, size: 14, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        '$reportCount report${reportCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A8D9A),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Content preview
                  Text(
                    truncatedCaption.isNotEmpty
                        ? truncatedCaption
                        : '(no caption)',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF555555),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Action buttons
                  Row(
                    children: [
                      _actionBtn(
                        label: 'Approve',
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                        textColor: const Color(0xFF4CAF50),
                        onTap: () => _approvePost(report),
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        label: 'Remove Post',
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                        textColor: const Color(0xFFFF3B30),
                        onTap: () => _removePost(report),
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        label: 'Ban User',
                        color: const Color(0xFF1A1D27),
                        textColor: Colors.white,
                        onTap: () => _banUser(report),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
