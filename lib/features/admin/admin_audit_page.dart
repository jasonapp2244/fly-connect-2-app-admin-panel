import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';

class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  List<Map<String, dynamic>> _entries = [];
  String _filter = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  Future<void> _fetchEntries() async {
    setState(() => _loading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('audit_log')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();
      if (!mounted) return;
      setState(() {
        _entries = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      debugPrint('[AdminAudit] fetch failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matchesAction(String action, String filter) {
    switch (filter) {
      case 'bans':
        return action.startsWith('ban');
      case 'approvals':
        return action.startsWith('approve');
      case 'rejections':
        return action.startsWith('reject');
      case 'deletions':
        return action.startsWith('delete') || action.startsWith('remove');
      default:
        return true;
    }
  }

  List<Map<String, dynamic>> get _filteredEntries {
    if (_filter == 'all') return _entries;
    return _entries
        .where((e) => _matchesAction((e['action'] ?? '') as String, _filter))
        .toList();
  }

  int get _todayCount {
    final now = DateTime.now();
    return _entries.where((e) {
      final ts = e['timestamp'];
      if (ts is! Timestamp) return false;
      final d = ts.toDate();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
  }

  int get _weekCount {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _entries.where((e) {
      final ts = e['timestamp'];
      if (ts is! Timestamp) return false;
      return ts.toDate().isAfter(cutoff);
    }).length;
  }

  int get _bansCount => _entries
      .where((e) => ((e['action'] ?? '') as String).startsWith('ban'))
      .length;
  int get _approvalsCount => _entries
      .where((e) => ((e['action'] ?? '') as String).startsWith('approve'))
      .length;

  Color _actionColor(String action) {
    if (action.startsWith('ban') ||
        action.startsWith('delete') ||
        action.startsWith('remove')) {
      return AppColors.error;
    }
    if (action.startsWith('approve')) return AppColors.online;
    if (action.startsWith('reject')) return AppColors.warning;
    return Colors.blue;
  }

  String _fmtTime(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    final filtered = _filteredEntries;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatCard("Today's Actions", _todayCount, Colors.blue),
              const SizedBox(width: 12),
              _buildStatCard('This Week', _weekCount, AppColors.dark),
              const SizedBox(width: 12),
              _buildStatCard('Bans', _bansCount, AppColors.error),
              const SizedBox(width: 12),
              _buildStatCard('Approvals', _approvalsCount, AppColors.online),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _filterPill('All', 'all'),
              const SizedBox(width: 8),
              _filterPill('Bans', 'bans'),
              const SizedBox(width: 8),
              _filterPill('Approvals', 'approvals'),
              const SizedBox(width: 8),
              _filterPill('Rejections', 'rejections'),
              const SizedBox(width: 8),
              _filterPill('Deletions', 'deletions'),
              const Spacer(),
              SizedBox(
                width: 110,
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('Export CSV'),
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('No audit entries',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...filtered.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildRow(e),
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

  Widget _buildRow(Map<String, dynamic> e) {
    final action = (e['action'] ?? 'unknown') as String;
    final adminName = (e['adminName'] ?? 'Unknown admin') as String;
    final targetType = (e['targetType'] ?? '') as String;
    final targetId = (e['targetId'] ?? '') as String;
    final details = (e['details'] ?? '') as String;
    final ip = (e['ipAddress'] ?? '') as String;
    final color = _actionColor(action);
    final initial = adminName.isNotEmpty ? adminName[0].toUpperCase() : '?';

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(_fmtTime(e['timestamp']),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.dark,
            child: Text(initial,
                style:
                    const TextStyle(color: Colors.white, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(adminName,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(action,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              details.isNotEmpty
                  ? details
                  : '$targetType${targetId.isNotEmpty ? ' · $targetId' : ''}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (ip.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(ip,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace')),
          ],
        ],
      ),
    );
  }
}
