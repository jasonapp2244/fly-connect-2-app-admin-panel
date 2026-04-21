import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/providers/providers.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'like': return Icons.favorite;
      case 'comment': return Icons.chat_bubble;
      case 'follow': return Icons.person_add;
      case 'match': return Icons.favorite_border;
      case 'message': return Icons.message;
      case 'event': return Icons.event;
      default: return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'like': return Colors.red;
      case 'match': return Colors.pink;
      case 'comment': return Colors.blue;
      case 'follow': return Colors.green;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.dark), onPressed: () => context.pop()),
        title: Text('Notifications', style: AppTextStyles.h3.copyWith(color: AppColors.dark)),
        actions: [TextButton(
          onPressed: () => context.read<NotificationProvider>().markAllAsRead(),
          child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontSize: 13)),
        )],
      ),
      body: Consumer<NotificationProvider>(
        builder: (ctx, provider, _) {
          final notifications = provider.notifications;
          if (notifications.isEmpty) {
            return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none, size: 72, color: AppColors.dark.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Text('No notifications yet', style: TextStyle(color: AppColors.dark.withValues(alpha: 0.5))),
            ],
          ));
          }
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (_, i) {
              final n = notifications[i];
              return Dismissible(
                key: Key(n.id),
                direction: DismissDirection.endToStart,
                background: Container(color: Colors.red, alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline, color: Colors.white)),
                onDismissed: (_) => provider.delete(n.id),
                child: InkWell(
                  onTap: () {
                    provider.markAsRead(n.id);
                    if (n.deepLink != null) context.push(n.deepLink!);
                  },
                  child: Container(
                    color: n.isRead ? null : AppColors.primary.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 44, height: 44,
                        decoration: BoxDecoration(color: _colorForType(n.type).withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: Icon(_iconForType(n.type), color: _colorForType(n.type), size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.title, style: AppTextStyles.labelMedium.copyWith(color: AppColors.dark,
                          fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(n.body, style: TextStyle(color: AppColors.dark.withValues(alpha: 0.6), fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(timeago.format(n.createdAt),
                          style: TextStyle(color: AppColors.dark.withValues(alpha: 0.4), fontSize: 11)),
                      ])),
                      if (!n.isRead) Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
