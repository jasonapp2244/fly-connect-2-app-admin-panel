import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/providers/providers.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _range = '7 days';
  List<int> _barData = [];
  List<String> _barLabels = [];
  bool _loadingChart = true;
  int _totalPosts = 0;
  int _totalViews = 0;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    setState(() => _loadingChart = true);
    final uid = context.read<UserProvider>().currentUser?.uid;
    if (uid == null) { setState(() => _loadingChart = false); return; }

    try {
      int days;
      switch (_range) {
        case '7 days': days = 7; break;
        case '90 days': days = 90; break;
        default: days = 30;
      }

      final cutoff = DateTime.now().subtract(Duration(days: days));
      final snap = await FirebaseFirestore.instance.collection('posts')
          .where('authorId', isEqualTo: uid)
          .where('createdAt', isGreaterThan: cutoff)
          .orderBy('createdAt')
          .get();

      _totalPosts = snap.docs.length;
      _totalViews = snap.docs.fold<int>(0, (sum, d) => sum + ((d.data()['views'] ?? 0) as int));

      if (days == 7) {
        // Group by day of week
        final counts = List.filled(7, 0);
        for (final doc in snap.docs) {
          final ts = doc.data()['createdAt'];
          if (ts is Timestamp) {
            counts[ts.toDate().weekday - 1]++;
          }
        }
        _barData = counts;
        _barLabels = _dayNames;
      } else if (days == 30) {
        // Group by week
        final counts = List.filled(4, 0);
        for (final doc in snap.docs) {
          final ts = doc.data()['createdAt'];
          if (ts is Timestamp) {
            final daysAgo = DateTime.now().difference(ts.toDate()).inDays;
            final weekIdx = (3 - (daysAgo ~/ 7)).clamp(0, 3);
            counts[weekIdx]++;
          }
        }
        _barData = counts;
        _barLabels = ['W1', 'W2', 'W3', 'W4'];
      } else {
        // Group by month
        final Map<int, int> monthCounts = {};
        for (final doc in snap.docs) {
          final ts = doc.data()['createdAt'];
          if (ts is Timestamp) {
            final m = ts.toDate().month;
            monthCounts[m] = (monthCounts[m] ?? 0) + 1;
          }
        }
        final sortedMonths = monthCounts.keys.toList()..sort();
        _barData = sortedMonths.map((m) => monthCounts[m]!).toList();
        _barLabels = sortedMonths.map((m) => _monthNames[m - 1]).toList();
      }
      if (_barData.isEmpty) { _barData = [0]; _barLabels = ['—']; }
    } catch (_) {
      _barData = [0]; _barLabels = ['—'];
    }
    if (mounted) setState(() => _loadingChart = false);
  }

  List<int> get _yAxisSteps {
    if (_barData.isEmpty) return [0];
    final maxVal = _barData.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 10) return [0, 2, 5, 8, 10];
    if (maxVal <= 100) return [0, 25, 50, 75, 100];
    if (maxVal <= 250) return [0, 50, 100, 150, 200];
    return [0, 150, 300, 450, 600];
  }

  @override
  Widget build(BuildContext context) {
    final bars = _barData.isEmpty ? [0] : _barData;
    final maxBar = bars.reduce((a, b) => a > b ? a : b).toDouble().clamp(1.0, double.infinity);
    final promotions = context.watch<PromotionProvider>().promotions;
    final realFollowers = context.watch<UserProvider>().currentUser?.followerCount ?? 0;
    final totalPromoViews = promotions.fold<int>(0, (s, p) => s + p.views);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
          onPressed: () => GoRouter.of(context).pop(),
        ),
        title: const Text('Analytics', style: AppTextStyles.labelLarge),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButton<String>(
              value: _range,
              underline: const SizedBox(),
              style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
              items: const [
                DropdownMenuItem(value: '7 days', child: Text('7 days')),
                DropdownMenuItem(value: '30 days', child: Text('30 days')),
                DropdownMenuItem(value: '90 days', child: Text('90 days')),
              ],
              onChanged: (v) { setState(() => _range = v!); _loadChartData(); },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Top metric cards
          Row(children: [
            Expanded(child: _MetricCard(value: realFollowers.toString(), label: 'Followers')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(value: '$_totalPosts', label: 'Posts')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(value: '$totalPromoViews', label: 'Promo Views')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(value: '$_totalViews', label: 'Post Views')),
          ]),

          const SizedBox(height: 24),

          const Text('Post Activity', style: AppTextStyles.labelLarge),
          const SizedBox(height: 12),

          if (_loadingChart)
            const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else
          Container(
            height: 220,
            padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
            decoration: BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Y-axis labels
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _yAxisSteps.reversed.map((v) =>
                    Text(v.toString(),
                      style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 9))).toList(),
                ),
              ),
              const SizedBox(width: 6),
              // Bars
              Expanded(child: Column(children: [
                Expanded(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(bars.length, (i) {
                    final frac = bars[i] / maxBar;
                    return Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: frac,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        )),
                      ],
                    ));
                  }),
                )),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(bars.length, (i) => Expanded(
                    child: Text(_barLabels[i],
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 9)),
                  )),
                ),
              ])),
            ]),
          ),

          const SizedBox(height: 24),

          const Text('Promotion Performance', style: AppTextStyles.labelLarge),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: promotions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = promotions[i];
              final progress = p.maxRedemptions > 0
                  ? (p.currentRedemptions / p.maxRedemptions).clamp(0.0, 1.0)
                  : 0.0;
              return GestureDetector(
                onTap: () => context.push('/promotions/${p.id}'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.percent, color: AppColors.dark, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.title, style: AppTextStyles.labelMedium,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(p.isActive ? 'Active' : 'Expired',
                          style: TextStyle(
                            color: p.isActive ? Colors.green : Colors.red,
                            fontSize: 11, fontWeight: FontWeight.w600)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${p.views} views',
                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                        Text('${p.saves} saves', style: AppTextStyles.caption),
                      ]),
                    ]),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 4),
                    Text('${p.currentRedemptions}/${p.maxRedemptions} redemptions',
                      style: AppTextStyles.caption),
                  ]),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          const Text('Event Attendance', style: AppTextStyles.labelLarge),
          const SizedBox(height: 12),

          Consumer<EventProvider>(builder: (_, eventProvider, __) {
            final events = eventProvider.events.take(3).toList();
            if (events.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Center(
                  child: Text('No events yet',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final e = events[i];
              final progress = (e.rsvpCount / 50).clamp(0.0, 1.0);
              return GestureDetector(
                onTap: () => context.push('/business-event-management'),
                child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(e.title, style: AppTextStyles.labelMedium,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${e.rsvpCount}',
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                      const Text(' RSVPs', style: AppTextStyles.caption),
                    ]),
                  ]),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                ]),
              ),
              );
            },
            );
          }),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value, label;
  const _MetricCard({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: AppColors.dark, borderRadius: BorderRadius.circular(14)),
    child: Column(children: [
      Text(value, style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
      const SizedBox(height: 2),
      Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white70),
        textAlign: TextAlign.center),
    ]),
  );
}
