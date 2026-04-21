import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/real_providers.dart';

class SafeCheckHistoryScreen extends StatelessWidget {
  const SafeCheckHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final safeCheck = context.watch<SafeCheckProvider>();
    final auth = context.watch<AuthProvider>();
    final userId = auth.currentUser?.uid ?? '';
    final myCheckIns = safeCheck.checkIns
        .where((c) => c.userId == userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context)),
        title: const Text('SafeCheck History',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: myCheckIns.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.health_and_safety, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No check-ins yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Use SafeCheck on the Nearby screen\nto share your safety status.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ]))
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: myCheckIns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _CheckInCard(checkIn: myCheckIns[i]),
          ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  final SafeCheckModel checkIn;
  const _CheckInCard({required this.checkIn});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(checkIn.status);
    final isActive = checkIn.isActive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? color.withValues(alpha: 0.3) : Colors.grey.shade200)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isActive ? 0.15 : 0.08),
            shape: BoxShape.circle),
          child: Icon(_statusIcon(checkIn.status), color: color.withValues(alpha: isActive ? 1 : 0.5), size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_statusLabel(checkIn.status),
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15,
                color: isActive ? color : Colors.grey)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6)),
              child: Text(isActive ? 'Active' : 'Expired',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: isActive ? color : Colors.grey))),
          ]),
          if (checkIn.message != null) ...[
            const SizedBox(height: 4),
            Text(checkIn.message!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.location_on, size: 12, color: Colors.grey.shade400),
            const SizedBox(width: 2),
            Text(checkIn.city, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(width: 12),
            Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
            const SizedBox(width: 2),
            Text(_timeAgo(checkIn.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ])),
      ]),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── Status helpers (duplicated for self-contained file) ─────
Color _statusColor(String? status) => switch (status) {
  'safe'      => AppColors.online,
  'unsure'    => AppColors.warning,
  'need_help' => AppColors.error,
  _           => AppColors.primary,
};

IconData _statusIcon(String? status) => switch (status) {
  'safe'      => Icons.check_circle,
  'unsure'    => Icons.help,
  'need_help' => Icons.warning,
  _           => Icons.circle,
};

String _statusLabel(String? status) => switch (status) {
  'safe'      => 'Safe',
  'unsure'    => 'Unsure',
  'need_help' => 'Need Help',
  _           => 'Unknown',
};
