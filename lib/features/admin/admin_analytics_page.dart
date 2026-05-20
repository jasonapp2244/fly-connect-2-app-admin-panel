import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  Map<String, int> _counts = {};
  bool _loading = true;

  static const List<String> _collections = [
    'users',
    'posts',
    'events',
    'groups',
    'chats',
    'safeChecks',
    'matches',
    'trips',
    'promotions',
    'notifications',
  ];

  static const Map<String, Color> _collectionColors = {
    'users': Color(0xFF4CAF50),
    'posts': Color(0xFF2196F3),
    'events': Color(0xFFFF9500),
    'groups': Color(0xFFD4F53C),
    'chats': Color(0xFF9C27B0),
    'safeChecks': Color(0xFFFF3B30),
    'matches': Color(0xFFE91E63),
    'trips': Color(0xFF00BCD4),
    'promotions': Color(0xFFFF5722),
    'notifications': Color(0xFF607D8B),
  };

  static const Map<String, IconData> _collectionIcons = {
    'users': Icons.people_outline,
    'posts': Icons.article_outlined,
    'events': Icons.event_outlined,
    'groups': Icons.group_outlined,
    'chats': Icons.chat_bubble_outline,
    'safeChecks': Icons.health_and_safety_outlined,
    'matches': Icons.favorite_border,
    'trips': Icons.flight_outlined,
    'promotions': Icons.local_offer_outlined,
    'notifications': Icons.notifications_outlined,
  };

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    setState(() => _loading = true);
    final Map<String, int> counts = {};
    try {
      for (final collection in _collections) {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection(collection)
              .count()
              .get();
          counts[collection] = snapshot.count ?? 0;
        } catch (_) {
          try {
            final snapshot = await FirebaseFirestore.instance
                .collection(collection)
                .get();
            counts[collection] = snapshot.docs.length;
          } catch (_) {
            counts[collection] = 0;
          }
        }
      }
    } catch (e) {
      debugPrint('[AdminAnalytics] fetch failed: $e');
    } finally {
      if (mounted) setState(() { _counts = counts; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.expand(
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final maxCount = _counts.values.isEmpty
        ? 1
        : _counts.values.reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top stat cards ───────────────────────────
          Row(
            children: [
              _buildStatCard(
                  'Total Users', _counts['users'] ?? 0, AppColors.online),
              const SizedBox(width: 12),
              _buildStatCard(
                  'Total Posts', _counts['posts'] ?? 0, Colors.blue),
              const SizedBox(width: 12),
              _buildStatCard(
                  'Total Events', _counts['events'] ?? 0, AppColors.warning),
              const SizedBox(width: 12),
              _buildStatCard(
                  'Total Groups', _counts['groups'] ?? 0, AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _buildStatCard(
                  'Matches', _counts['matches'] ?? 0, const Color(0xFFE91E63)),
              const SizedBox(width: 12),
              _buildStatCard(
                  'Trips', _counts['trips'] ?? 0, const Color(0xFF00BCD4)),
              const SizedBox(width: 12),
              _buildStatCard('SafeChecks', _counts['safeChecks'] ?? 0,
                  AppColors.error),
              const SizedBox(width: 12),
              _buildStatCard('Promotions', _counts['promotions'] ?? 0,
                  const Color(0xFFFF5722)),
            ],
          ),
          const SizedBox(height: 24),

          // ── Feature Usage Bar Chart ───────────────────
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
                      'Feature Usage',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    IconButton(
                      onPressed: _fetchCounts,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      color: AppColors.textSecondary,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Responsive bar chart via LayoutBuilder
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxBarWidth = constraints.maxWidth - 160;
                    return Column(
                      children: _collections
                          .where((c) => c != 'notifications')
                          .map((collection) {
                        final count = _counts[collection] ?? 0;
                        final barWidth = maxCount > 0
                            ? (count / maxCount) * maxBarWidth
                            : 0.0;
                        final color = _collectionColors[collection] ??
                            AppColors.textSecondary;
                        final icon = _collectionIcons[collection] ??
                            Icons.circle_outlined;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: [
                              Icon(icon, size: 16, color: color),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 88,
                                child: Text(
                                  _formatLabel(collection),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                height: 22,
                                width: barWidth.clamp(4, maxBarWidth).toDouble(),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$count',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Engagement Metrics Table ──────────────────
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
                const Text(
                  'All Collections',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.dark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text('Collection',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text('Documents',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                ...List.generate(_collections.length, (index) {
                  final collection = _collections[index];
                  final count = _counts[collection] ?? 0;
                  final isEven = index % 2 == 0;
                  final color = _collectionColors[collection] ??
                      AppColors.textSecondary;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isEven ? AppColors.backgroundGrey : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _formatLabel(collection),
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            '$count',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: color),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLabel(String collection) {
    switch (collection) {
      case 'safeChecks':
        return 'SafeChecks';
      case 'notifications':
        return 'Notifications';
      default:
        return collection[0].toUpperCase() + collection.substring(1);
    }
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
}
