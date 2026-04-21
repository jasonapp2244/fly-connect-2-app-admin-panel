import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _totalUsers = 0;
  int _activeToday = 0;
  int _verifiedUsers = 0;
  int _safeCheckAlerts = 0;
  int _reportedContent = 0;
  int _totalPosts = 0;
  int _totalEvents = 0;
  int _totalGroups = 0;
  List<Map<String, dynamic>> _recentActivity = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUserStats(),
      _loadSafeCheckAlerts(),
      _loadReportedContent(),
      _loadCollectionCounts(),
      _loadRecentActivity(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadUserStats() async {
    try {
      // Total users
      final totalSnap = await _db.collection('users').count().get();
      _totalUsers = totalSnap.count ?? 0;

      // Active today (lastSeen within last 24 hours)
      final yesterday = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)),
      );
      final activeSnap = await _db
          .collection('users')
          .where('lastSeen', isGreaterThan: yesterday)
          .count()
          .get();
      _activeToday = activeSnap.count ?? 0;

      // Verified users
      final verifiedSnap = await _db
          .collection('users')
          .where('isVerified', isEqualTo: true)
          .count()
          .get();
      _verifiedUsers = verifiedSnap.count ?? 0;
    } catch (_) {
      final snap = await _db.collection('users').get();
      final docs = snap.docs;
      _totalUsers = docs.length;
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      _activeToday = docs.where((d) {
        final raw = d.data()['lastSeen'];
        if (raw is Timestamp) return raw.toDate().isAfter(yesterday);
        return false;
      }).length;
      _verifiedUsers = docs.where((d) => d.data()['isVerified'] == true).length;
    }
  }

  Future<void> _loadSafeCheckAlerts() async {
    try {
      final snap = await _db
          .collection('safeChecks')
          .where('status', isEqualTo: 'need_help')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .count()
          .get();
      _safeCheckAlerts = snap.count ?? 0;
    } catch (_) {
      final snap = await _db
          .collection('safeChecks')
          .where('status', isEqualTo: 'need_help')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();
      _safeCheckAlerts = snap.docs.length;
    }
  }

  Future<void> _loadReportedContent() async {
    try {
      final snap = await _db
          .collection('posts')
          .where('isReported', isEqualTo: true)
          .count()
          .get();
      _reportedContent = snap.count ?? 0;
    } catch (_) {
      final snap = await _db
          .collection('posts')
          .where('isReported', isEqualTo: true)
          .get();
      _reportedContent = snap.docs.length;
    }
  }

  Future<void> _loadCollectionCounts() async {
    try {
      final results = await Future.wait([
        _db.collection('posts').count().get(),
        _db.collection('events').count().get(),
        _db.collection('groups').count().get(),
      ]);
      _totalPosts = results[0].count ?? 0;
      _totalEvents = results[1].count ?? 0;
      _totalGroups = results[2].count ?? 0;
    } catch (_) {
      final results = await Future.wait([
        _db.collection('posts').get(),
        _db.collection('events').get(),
        _db.collection('groups').get(),
      ]);
      _totalPosts = results[0].docs.length;
      _totalEvents = results[1].docs.length;
      _totalGroups = results[2].docs.length;
    }
  }

  Future<void> _loadRecentActivity() async {
    try {
      final snap = await _db
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(12)
          .get();
      _recentActivity = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (_) {
      // Non-fatal \u2014 leave list empty and let the empty-state render
      _recentActivity = [];
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final dateStr = '${months[now.month - 1]} ${now.day}, ${now.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date subtitle ─────────────────────────────
          Text(
            dateStr,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // ── Row 1: Safety & moderation ──────────────
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  label: 'Total Users',
                  value: _totalUsers.toString(),
                  subtitle: 'Registered accounts',
                  accentColor: AppColors.primary,
                  icon: Icons.people_outline,
                  onTap: () => context.go('/admin/users'),
                ),
                _StatCard(
                  label: 'Active Today',
                  value: _activeToday.toString(),
                  subtitle: 'Seen in last 24h',
                  accentColor: AppColors.online,
                  icon: Icons.online_prediction,
                ),
                _StatCard(
                  label: 'Verified Users',
                  value: _verifiedUsers.toString(),
                  subtitle: 'ID verified',
                  accentColor: Colors.blue,
                  icon: Icons.verified_outlined,
                ),
                _StatCard(
                  label: 'SafeCheck Alerts',
                  value: _safeCheckAlerts.toString(),
                  subtitle: 'Need help now',
                  accentColor: AppColors.warning,
                  icon: Icons.health_and_safety_outlined,
                  onTap: () => context.go('/admin/safecheck'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Row 2: Content stats ─────────────────────
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  label: 'Reported Content',
                  value: _reportedContent.toString(),
                  subtitle: 'Flagged posts',
                  accentColor: AppColors.error,
                  icon: Icons.flag_outlined,
                  onTap: () => context.go('/admin/content'),
                ),
                _StatCard(
                  label: 'Total Posts',
                  value: _totalPosts.toString(),
                  subtitle: 'All posts',
                  accentColor: const Color(0xFF2196F3),
                  icon: Icons.article_outlined,
                ),
                _StatCard(
                  label: 'Total Events',
                  value: _totalEvents.toString(),
                  subtitle: 'All events',
                  accentColor: const Color(0xFF9C27B0),
                  icon: Icons.event_outlined,
                  onTap: () => context.go('/admin/events'),
                ),
                _StatCard(
                  label: 'Total Groups',
                  value: _totalGroups.toString(),
                  subtitle: 'Communities',
                  accentColor: const Color(0xFF00BCD4),
                  icon: Icons.group_outlined,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Quick Actions ────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuickActionButton(
                        icon: Icons.people_outline,
                        label: 'Manage Users',
                        onTap: () => context.go('/admin/users'),
                      ),
                      _QuickActionButton(
                        icon: Icons.flag_outlined,
                        label: 'Review Reports',
                        onTap: () => context.go('/admin/content'),
                      ),
                      _QuickActionButton(
                        icon: Icons.health_and_safety_outlined,
                        label: 'SafeCheck Queue',
                        onTap: () => context.go('/admin/safecheck'),
                      ),
                      _QuickActionButton(
                        icon: Icons.notifications_outlined,
                        label: 'Send Notification',
                        onTap: () => context.go('/admin/notifications'),
                      ),
                      _QuickActionButton(
                        icon: Icons.event_outlined,
                        label: 'Approve Events',
                        onTap: () => context.go('/admin/events'),
                      ),
                      _QuickActionButton(
                        icon: Icons.bar_chart_rounded,
                        label: 'View Analytics',
                        onTap: () => context.go('/admin/analytics'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Recent Activity ──────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Posts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/admin/content'),
                          child: const Text(
                            'View Content',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Table header
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: _TableHeader('User')),
                        Expanded(flex: 2, child: _TableHeader('Action')),
                        Expanded(flex: 4, child: _TableHeader('Details')),
                        Expanded(flex: 2, child: _TableHeader('Time')),
                        Expanded(flex: 2, child: _TableHeader('Status')),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  if (_recentActivity.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No recent activity',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ..._recentActivity.map((post) => _buildActivityRow(post)),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> post) {
    final authorName = post['authorName'] as String? ?? 'Unknown';
    final caption = post['caption'] as String? ?? '';
    final truncated = caption.length > 50 ? '${caption.substring(0, 50)}...' : caption;
    final isReported = post['isReported'] == true;

    DateTime? createdAt;
    final raw = post['createdAt'];
    if (raw is Timestamp) createdAt = raw.toDate();

    final initial = authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(initial,
                      style: const TextStyle(
                          color: AppColors.dark,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(authorName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Post',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark)),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              truncated.isNotEmpty ? truncated : '(no caption)',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              createdAt != null ? _timeAgo(createdAt) : '--',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isReported
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AppColors.online.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isReported ? 'Reported' : 'Active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isReported ? AppColors.error : AppColors.online,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Action Button ─────────────────────────────────────
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundGrey,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Card ───────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color accentColor;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: onTap != null
              ? Border.all(color: AppColors.inputBorder)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: accentColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Table header label ──────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
