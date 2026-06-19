import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/providers/post_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushLikes = true;
  bool _pushComments = true;
  bool _pushMatches = true;
  bool _pushMessages = true;
  bool _pushEvents = false;
  bool _profilePublic = true;
  bool _showOnNearby = true;
  bool _showAirline = true;
  bool _shareLocation = true;
  bool _approxLocationOnly = true;
  String _nearbyVisibility = 'all'; // 'all', 'friends', 'verified'
  bool _pushSafeCheck = true;
  bool _loadingLogout = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadPreferences();
  }

  void _loadPreferences() {
    final userProvider = context.read<UserProvider>();
    final notifPrefs = userProvider.notificationPrefs;
    if (notifPrefs != null) {
      setState(() {
        _pushLikes = notifPrefs['likes'] as bool? ?? true;
        _pushComments = notifPrefs['comments'] as bool? ?? true;
        _pushMatches = notifPrefs['matches'] as bool? ?? true;
        _pushMessages = notifPrefs['messages'] as bool? ?? true;
        _pushEvents = notifPrefs['events'] as bool? ?? false;
        _pushSafeCheck = notifPrefs['safeCheck'] as bool? ?? true;
      });
    }
    final privacy = userProvider.privacySettings;
    if (privacy != null) {
      setState(() {
        _profilePublic = privacy['profilePublic'] as bool? ?? true;
        _showOnNearby = privacy['showOnNearby'] as bool? ?? true;
        _showAirline = privacy['showAirline'] as bool? ?? true;
        _shareLocation = privacy['shareLocation'] as bool? ?? true;
        _approxLocationOnly = privacy['approxLocationOnly'] as bool? ?? true;
        _nearbyVisibility = privacy['nearbyVisibility'] as String? ?? 'all';
      });
    }
  }

  Future<void> _saveNotificationPrefs() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    final prefs = {
      'likes': _pushLikes, 'comments': _pushComments, 'matches': _pushMatches,
      'messages': _pushMessages, 'events': _pushEvents, 'safeCheck': _pushSafeCheck,
    };
    try {
      await context.read<UserProvider>().updateProfile(uid, {'notificationPrefs': prefs});
    } catch (_) {}
  }

  Future<void> _savePrivacySettings() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    final settings = {
      'profilePublic': _profilePublic, 'showOnNearby': _showOnNearby,
      'showAirline': _showAirline, 'shareLocation': _shareLocation,
      'approxLocationOnly': _approxLocationOnly, 'nearbyVisibility': _nearbyVisibility,
    };
    try {
      await context.read<UserProvider>().updateProfile(uid, {'privacySettings': settings});
    } catch (_) {}
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = '${info.version} (${info.buildNumber})');
    } catch (_) {
      // Fall back to pubspec version if platform call fails
      if (mounted) setState(() => _appVersion = '—');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Settings', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(children: [
        _Section(title: 'Account', children: [
          _Tile(icon: Icons.person_outline, label: 'Edit Profile',
            onTap: () => context.push(AppRoutes.editProfileDetails)),
          _Tile(icon: Icons.lock_outline, label: 'Change Password',
            onTap: () => _changePasswordSheet(context)),
          _Tile(icon: Icons.phone_outlined, label: 'Phone Number',
            onTap: () => _showInfoSheet(context, 'Update Phone', 'Coming soon')),
          _Tile(icon: Icons.email_outlined, label: 'Email Address',
            onTap: () => _showInfoSheet(context, 'Update Email', 'Coming soon')),
        ]),
        _Section(title: 'Notifications', children: [
          _ToggleTile(icon: Icons.favorite_outline, label: 'Likes', value: _pushLikes,
            onChanged: (v) { setState(() => _pushLikes = v); _saveNotificationPrefs(); }),
          _ToggleTile(icon: Icons.chat_bubble_outline, label: 'Comments', value: _pushComments,
            onChanged: (v) { setState(() => _pushComments = v); _saveNotificationPrefs(); }),
          _ToggleTile(icon: Icons.favorite_border, label: 'New Matches', value: _pushMatches,
            onChanged: (v) { setState(() => _pushMatches = v); _saveNotificationPrefs(); }),
          _ToggleTile(icon: Icons.message_outlined, label: 'Messages', value: _pushMessages,
            onChanged: (v) { setState(() => _pushMessages = v); _saveNotificationPrefs(); }),
          _ToggleTile(icon: Icons.event_outlined, label: 'Events Near You', value: _pushEvents,
            onChanged: (v) { setState(() => _pushEvents = v); _saveNotificationPrefs(); }),
          _ToggleTile(icon: Icons.health_and_safety, label: 'SafeCheck Alerts', value: _pushSafeCheck,
            onChanged: (v) { setState(() => _pushSafeCheck = v); _saveNotificationPrefs(); }),
        ]),
        _Section(title: 'Privacy', children: [
          _ToggleTile(icon: Icons.public, label: 'Public Profile', value: _profilePublic,
            onChanged: (v) { setState(() => _profilePublic = v); _savePrivacySettings(); }),
          _ToggleTile(icon: Icons.location_on_outlined, label: 'Show on Nearby Map', value: _showOnNearby,
            onChanged: (v) { setState(() => _showOnNearby = v); _savePrivacySettings(); }),
          _ToggleTile(icon: Icons.flight, label: 'Show Airline & Position', value: _showAirline,
            onChanged: (v) { setState(() => _showAirline = v); _savePrivacySettings(); }),
          _ToggleTile(icon: Icons.share_location, label: 'Share Location for SafeCheck', value: _shareLocation,
            onChanged: (v) { setState(() => _shareLocation = v); _savePrivacySettings(); }),
          _ToggleTile(icon: Icons.blur_on, label: 'Approximate Location Only', value: _approxLocationOnly,
            onChanged: (v) { setState(() => _approxLocationOnly = v); _savePrivacySettings(); }),
          _Tile(icon: Icons.visibility, label: 'SafeCheck Visibility',
            trailing: Text(
              _nearbyVisibility == 'all' ? 'Everyone'
                : _nearbyVisibility == 'friends' ? 'Friends Only' : 'Verified Users',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
            onTap: () => _showVisibilitySheet(context)),
          _Tile(icon: Icons.block, label: 'Blocked Users',
            onTap: () => _blockedUsersSheet(context)),
          _Tile(icon: Icons.download_for_offline_outlined, label: 'Request My Data',
            onTap: () => _requestDataSheet(context)),
        ]),
        // Developer testing removed for production
        _Section(title: 'Support', children: [
          _Tile(icon: Icons.help_outline, label: 'Help & Support',
            onTap: () => _showInfoSheet(context, 'Help & Support', 'Contact: support@flyconnect.app')),
          _Tile(icon: Icons.description_outlined, label: 'Terms of Service',
            onTap: () => _showInfoSheet(context, 'Terms of Service', 'View our terms at flyconnect.app/terms')),
          _Tile(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy',
            onTap: () => _showInfoSheet(context, 'Privacy Policy', 'View at flyconnect.app/privacy')),
          _Tile(icon: Icons.info_outline, label: 'App Version',
            trailing: Text(_appVersion.isEmpty ? '…' : _appVersion,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            onTap: () {}),
        ]),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          label: const Text('Delete Account', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () => _deleteAccountSheet(context))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: ElevatedButton.icon(
            icon: _loadingLogout
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.logout, size: 20),
            label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dark, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              final router = GoRouter.of(context);
              final confirmed = await showConfirmDialog(
                context,
                title: 'Sign out?',
                message: "You'll need to sign in again to access your account.",
                confirmLabel: 'Sign out',
                isDestructive: true,
              );
              if (!confirmed) return;
              if (!mounted) return;
              setState(() => _loadingLogout = true);
              await authProvider.logout();
              router.go(AppRoutes.login);
            })),
      ]),
    );
  }

  void _changePasswordSheet(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Change Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: currentCtrl, obscureText: true,
            decoration: _inputDec('Current password')),
          const SizedBox(height: 12),
          TextField(controller: newCtrl, obscureText: true,
            decoration: _inputDec('New password')),
          const SizedBox(height: 12),
          TextField(controller: confirmCtrl, obscureText: true,
            decoration: _inputDec('Confirm new password')),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
              padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () async {
              final current = currentCtrl.text;
              final newPass = newCtrl.text;
              final confirm = confirmCtrl.text;

              // Validation
              if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Please fill in all fields'),
                  backgroundColor: Colors.red));
                return;
              }
              if (newPass.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('New password must be at least 8 characters'),
                  backgroundColor: Colors.red));
                return;
              }
              if (newPass != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Passwords do not match'),
                  backgroundColor: Colors.red));
                return;
              }

              final user = FirebaseAuth.instance.currentUser;
              if (user == null || user.email == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Please sign in again to change your password.'),
                  backgroundColor: Colors.red));
                return;
              }

              try {
                // Re-authenticate with the current password (Firebase requirement
                // for sensitive operations on sessions older than a few minutes).
                final cred = EmailAuthProvider.credential(
                  email: user.email!,
                  password: current,
                );
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(newPass);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Password updated successfully'),
                  backgroundColor: AppColors.online));
              } on FirebaseAuthException catch (e) {
                if (!context.mounted) return;
                String msg;
                switch (e.code) {
                  case 'wrong-password':
                  case 'invalid-credential':
                    msg = 'Current password is incorrect.';
                    break;
                  case 'weak-password':
                    msg = 'New password is too weak.';
                    break;
                  case 'requires-recent-login':
                    msg = 'Please sign out and sign in again, then try.';
                    break;
                  default:
                    msg = e.message ?? 'Could not update password.';
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(msg), backgroundColor: Colors.red));
              }
            },
            child: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)))),
        ])));
  }

  void _showVisibilitySheet(BuildContext context) {
    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('SafeCheck Visibility', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _nearbyVisibility,
            onChanged: (val) {
              setState(() => _nearbyVisibility = val!);
              _savePrivacySettings();
              Navigator.pop(context);
            },
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ...['all', 'friends', 'verified'].map((v) => RadioListTile<String>(
                title: Text(v == 'all' ? 'Everyone' : v == 'friends' ? 'Friends Only' : 'Verified Users Only'),
                value: v,
                activeColor: AppColors.dark,
              )),
            ]),
          ),
        ])));
  }

  /// GDPR / CCPA "right to access" self-serve.
  /// Writes a doc to `gdpr_requests` with type='export'; the admin
  /// Audit panel processes the queue and an admin (or a Cloud Function
  /// when wired) compiles + emails the export.
  void _requestDataSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),
          const Text('Request Your Data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'You can request a copy of all data we hold about you. '
              'Per GDPR / CCPA we will respond within 30 days. The export '
              'is sent to your account email.',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 16),
          const Text('What\'s included:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 6),
          _bullet('Your profile (name, email, photos, bio)'),
          _bullet('Your posts, comments, and likes'),
          _bullet('Your chats and SafeCheck history'),
          _bullet('Your trip history and group memberships'),
          _bullet('Audit log of admin actions affecting you (if any)'),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                Navigator.pop(ctx);
                return;
              }
              try {
                await FirebaseFirestore.instance.collection('gdpr_requests').add({
                  'userId': user.uid,
                  'userName': user.displayName ?? '',
                  'userEmail': user.email ?? '',
                  'requestType': 'export',
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                  'notes': 'User-initiated via Settings → Request My Data',
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Request submitted. We will email you within 30 days.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 4),
                  ));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Could not submit request: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            child: const Text('Submit Request',
                style: TextStyle(fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _blockedUsersSheet(BuildContext context) {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3,
        expand: false,
        builder: (sheetCtx, ctrl) => Column(children: [
          const Padding(padding: EdgeInsets.all(16),
            child: Text('Blocked Users', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Expanded(child: uid == null
            ? const Center(child: Text('Not signed in', style: TextStyle(color: Colors.grey)))
            : FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchBlockedUsers(uid),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  final blocked = snap.data ?? [];
                  if (blocked.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32),
                      child: Text('No blocked users', style: TextStyle(color: Colors.grey))));
                  }
                  return ListView.builder(
                    controller: ctrl,
                    itemCount: blocked.length,
                    itemBuilder: (_, i) {
                      final user = blocked[i];
                      final name = user['name'] as String? ?? 'Unknown';
                      final photo = user['photoUrl'] as String?;
                      final blockedUid = user['uid'] as String;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.dark,
                          backgroundImage: photo != null ? NetworkImage(photo) : null,
                          child: photo == null ? Text(name.isNotEmpty ? name[0] : '?',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)) : null,
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: TextButton(
                          onPressed: () async {
                            await context.read<PostProvider>().unblockUser(blockedUid);
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('$name unblocked'), backgroundColor: Colors.green));
                            }
                          },
                          child: const Text('Unblock', style: TextStyle(color: Colors.red, fontSize: 13)),
                        ),
                      );
                    },
                  );
                },
              )),
        ])));
  }

  Future<List<Map<String, dynamic>>> _fetchBlockedUsers(String uid) async {
    try {
      final blockedSnap = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('blocked').limit(50).get();
      if (blockedSnap.docs.isEmpty) return [];
      final futures = blockedSnap.docs.map((d) =>
          FirebaseFirestore.instance.collection('users').doc(d.id).get());
      final userDocs = await Future.wait(futures);
      return userDocs.where((d) => d.exists).map((d) {
        final data = d.data()!;
        data['uid'] = d.id;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _showInfoSheet(BuildContext context, String title, String message) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
        ])));
  }

  void _deleteAccountSheet(BuildContext context) {
    final confirmCtrl = TextEditingController();
    bool isDeleting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('Delete your account?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently:',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                _bullet('Delete your profile, posts, trips, and saved items'),
                _bullet('Remove you from groups, chats, and events'),
                _bullet('Anonymize any posts you made (shown as "[deleted user]")'),
                _bullet('Revoke access to all data linked to this account'),
                const SizedBox(height: 12),
                const Text(
                  'This cannot be undone.',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Type DELETE to confirm:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: confirmCtrl,
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: (confirmCtrl.text.trim() == 'DELETE' && !isDeleting)
                    ? () async {
                        setDialogState(() => isDeleting = true);
                        // GDPR audit trail: record the deletion request before
                        // we actually delete (the auth user goes away on next line).
                        final fbUser = FirebaseAuth.instance.currentUser;
                        if (fbUser != null) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('gdpr_requests').add({
                              'userId': fbUser.uid,
                              'userName': fbUser.displayName ?? '',
                              'userEmail': fbUser.email ?? '',
                              'requestType': 'delete',
                              'status': 'pending',
                              'createdAt': FieldValue.serverTimestamp(),
                              'notes': 'User-initiated via Settings → Delete Account',
                            });
                          } catch (_) {/* non-fatal */}
                        }
                        final ok = await context
                            .read<AuthProvider>()
                            .deleteAccount();
                        if (!context.mounted) return;
                        Navigator.pop(ctx);
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Your account has been deleted.')));
                          context.go(AppRoutes.login);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(context
                                    .read<AuthProvider>()
                                    .error ??
                                'Could not delete account.'),
                            backgroundColor: Colors.red,
                          ));
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Delete permanently'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('\u2022 ', style: TextStyle(color: Colors.black87)),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)),
          ),
        ]),
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.dark)));
}

class _Section extends StatelessWidget {
  final String title; final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        color: Colors.grey, letterSpacing: 0.8))),
    Container(margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: children)),
  ]);
}

class _Tile extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final Widget? trailing;
  const _Tile({required this.icon, required this.label, required this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 22, color: AppColors.textPrimary),
    title: Text(label, style: const TextStyle(fontSize: 15)),
    trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
    onTap: onTap,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))));
}

class _ToggleTile extends StatelessWidget {
  final IconData icon; final String label; final bool value; final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.icon, required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 22, color: AppColors.textPrimary),
    title: Text(label, style: const TextStyle(fontSize: 15)),
    trailing: CupertinoSwitch(value: value, activeTrackColor: AppColors.dark, onChanged: onChanged));
}
