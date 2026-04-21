import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() =>
      _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  String _target = 'all';
  bool _sending = false;
  List<Map<String, dynamic>> _recentNotifs = [];
  int _totalSent = 0;
  int _readCount = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchRecentNotifications();
    _fetchStats();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecentNotifications() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(12)
        .get();
    setState(() {
      _recentNotifs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> _fetchStats() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('notifications').count().get(),
        FirebaseFirestore.instance
            .collection('notifications')
            .where('isRead', isEqualTo: true)
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('notifications')
            .where('isRead', isEqualTo: false)
            .count()
            .get(),
      ]);
      setState(() {
        _totalSent = results[0].count ?? 0;
        _readCount = results[1].count ?? 0;
        _unreadCount = results[2].count ?? 0;
      });
    } catch (_) {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .get();
      setState(() {
        _totalSent = snap.docs.length;
        _readCount =
            snap.docs.where((d) => d.data()['isRead'] == true).length;
        _unreadCount =
            snap.docs.where((d) => d.data()['isRead'] != true).length;
      });
    }
  }

  Future<void> _sendNotification() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in title and message')),
      );
      return;
    }

    if (_target == 'city' && _cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a city name')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      Query query = FirebaseFirestore.instance.collection('users');
      if (_target == 'verified') {
        query = query.where('isVerified', isEqualTo: true);
      } else if (_target == 'city') {
        final city = _cityController.text.trim();
        query = query.where('city', isEqualTo: city);
      }

      final usersSnapshot = await query.get();
      final batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (final userDoc in usersSnapshot.docs) {
        final uid = userDoc.id;
        final notifRef =
            FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'uid': uid,
          'userId': uid,
          'title': _title.text.trim(),
          'body': _body.text.trim(),
          'type': 'admin',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        count++;
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification sent to $count users'),
            backgroundColor: AppColors.online,
          ),
        );
        _title.clear();
        _body.clear();
        _cityController.clear();
        await Future.wait([_fetchRecentNotifications(), _fetchStats()]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats row ────────────────────────────────
          Row(
            children: [
              _buildStatCard('Total Sent', _totalSent, AppColors.primary),
              const SizedBox(width: 12),
              _buildStatCard('Read', _readCount, AppColors.online),
              const SizedBox(width: 12),
              _buildStatCard('Unread', _unreadCount, AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
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
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.only(
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
                              _totalSent > 0
                                  ? '${((_readCount / _totalSent) * 100).toStringAsFixed(0)}%'
                                  : '—',
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Read Rate',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Main row: Compose + Recent ────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Compose
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(24),
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
                        'Compose Notification',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      const Text('Title',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _title,
                        decoration: _inputDecoration('Notification title'),
                      ),
                      const SizedBox(height: 16),

                      // Message
                      const Text('Message',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _body,
                        maxLines: 3,
                        decoration: _inputDecoration('Write your message...'),
                      ),
                      const SizedBox(height: 16),

                      // Target Audience
                      const Text('Target Audience',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildFilterPill('All Users', 'all'),
                          _buildFilterPill('Verified Only', 'verified'),
                          _buildFilterPill('By City', 'city'),
                        ],
                      ),

                      // City input — visible only when 'city' selected
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _target == 'city'
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: TextField(
                                  controller: _cityController,
                                  decoration: _inputDecoration(
                                      'Enter city name (e.g. New York)'),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 24),

                      // Send button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _sending ? null : _sendNotification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.dark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            textStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          child: _sending
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.dark),
                                )
                              : const Text('Send Notification'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Right: Recent Sent
              Expanded(
                flex: 4,
                child: Container(
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
                        'Recent Sent',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 14),
                      if (_recentNotifs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text('No recent notifications',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ),
                        )
                      else
                        ..._recentNotifs
                            .map((notif) => _buildRecentItem(notif)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
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
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildFilterPill(String label, String value) {
    final isSelected = _target == value;
    return GestureDetector(
      onTap: () => setState(() => _target = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.backgroundGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.inputBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.dark : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentItem(Map<String, dynamic> notif) {
    final createdAt = notif['createdAt'] != null
        ? (notif['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final isRead = notif['isRead'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isRead
              ? Colors.transparent
              : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  notif['title'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isRead
                      ? AppColors.online.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isRead ? 'Read' : 'Unread',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isRead ? AppColors.online : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            notif['body'] ?? '',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _timeAgo(createdAt),
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11),
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
}
