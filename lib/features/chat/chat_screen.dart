import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/models/models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('Messages', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () => context.push(AppRoutes.search)),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.black),
            tooltip: 'New message',
            onPressed: () => context.push(AppRoutes.nearby),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.dark,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [Tab(text: 'Direct'), Tab(text: 'Groups')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_DmList(), _GroupList()],
      ),
    );
  }
}

class _DmList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
        final dms = provider.chats.where((c) => c.type == 'dm').toList();

        if (dms.isEmpty) {
          return const _EmptyState(
          icon: Icons.chat_bubble_outline,
          message: 'No messages yet',
          sub: 'Find someone to connect with!');
        }

        return ListView.separated(
          itemCount: dms.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.backgroundGrey, indent: 76),
          itemBuilder: (context, i) => _ChatTile(chat: dms[i], currentUid: uid),
        );
      },
    );
  }
}

class _GroupList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
        final groups = provider.chats.where((c) => c.type == 'group').toList();

        if (groups.isEmpty) {
          return const _EmptyState(
          icon: Icons.group_outlined,
          message: 'No group chats',
          sub: 'Join a group to start chatting!');
        }

        return ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.backgroundGrey, indent: 76),
          itemBuilder: (context, i) => _ChatTile(chat: groups[i], currentUid: uid),
        );
      },
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String currentUid;
  const _ChatTile({required this.chat, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final unread = chat.unreadCount[currentUid] ?? 0;
    final isGroup = chat.type == 'group';
    final name = isGroup ? (chat.groupName ?? 'Group') : _otherName(chat, currentUid);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(children: [
        CircleAvatar(radius: 26,
          backgroundColor: isGroup ? AppColors.dark : AppColors.backgroundGrey,
          backgroundImage: (isGroup ? chat.groupPhotoUrl : null) != null
            ? NetworkImage(isGroup ? chat.groupPhotoUrl! : '') : null,
          child: (isGroup && chat.groupPhotoUrl == null)
            ? const Icon(Icons.group, color: AppColors.primary)
            : null),
        Positioned(bottom: 0, right: 0,
          child: Container(width: 12, height: 12,
            decoration: BoxDecoration(
              color: AppColors.online, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2)))),
      ]),
      title: Text(name, style: AppTextStyles.labelMedium),
      subtitle: Text(chat.lastMessage ?? 'No messages yet',
        style: AppTextStyles.bodySmall.copyWith(
          color: unread > 0 ? AppColors.dark : AppColors.textSecondary,
          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (chat.lastMessageAt != null)
          Text(timeago.format(chat.lastMessageAt!), style: AppTextStyles.caption),
        const SizedBox(height: 4),
        if (unread > 0)
          Container(width: 20, height: 20,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Center(child: Text(unread > 9 ? '9+' : '$unread',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.dark)))),
      ]),
      onTap: () => context.push('/conversation/${chat.id}?name=${Uri.encodeComponent(name)}&group=$isGroup'),
    );
  }

  String _otherName(ChatModel chat, String uid) {
    // Prefer a name embedded on the chat doc (set when the DM was created);
    // fall back to the group name or a generic "User". We no longer look
    // up against mockUsers \u2014 the chat doc should carry the participant name.
    final names = (chat as dynamic).participantNames;
    if (names is Map) {
      final otherUid = chat.participants.firstWhere((p) => p != uid, orElse: () => '');
      final name = names[otherUid];
      if (name is String && name.isNotEmpty) return name;
    }
    return chat.groupName ?? 'User';
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon; final String message, sub;
  const _EmptyState({required this.icon, required this.message, required this.sub});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, size: 64, color: Colors.grey.shade300),
    const SizedBox(height: 16),
    Text(message, style: AppTextStyles.h4),
    const SizedBox(height: 8),
    Text(sub, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
  ]));
}
