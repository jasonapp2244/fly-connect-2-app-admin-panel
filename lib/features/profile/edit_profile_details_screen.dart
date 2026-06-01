import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';

class EditProfileDetailsScreen extends StatefulWidget {
  const EditProfileDetailsScreen({super.key});
  @override State<EditProfileDetailsScreen> createState() => _EditProfileDetailsScreenState();
}

class _EditProfileDetailsScreenState extends State<EditProfileDetailsScreen> {
  final List<String> _allHobbies = [
    'Hiking', 'Photography', 'Cooking', 'Reading', 'Travel', 'Fitness',
    'Music', 'Art', 'Gaming', 'Yoga', 'Surfing', 'Cycling', 'Dancing',
    'Foodie', 'Movies', 'Camping', 'Swimming', 'Running', 'Coffee', 'Wine Tasting',
  ];
  List<String> _selectedHobbies = [];
  String _matchType = 'all';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().currentUser;
    if (user != null) {
      _selectedHobbies = List.from(user.hobbies);
      _matchType = user.matchType;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != null) {
      await context.read<UserProvider>().updateProfile(uid, {
        'hobbies': _selectedHobbies,
        'matchType': _matchType,
      });
    }
    setState(() => _saving = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved!'), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: _saving ? null : _save,
            child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
              // White AppBar — primary fails AA. Use dark for the Save label.
              : const Text('Save', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold, fontSize: 16))),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Match preference
        const Text('I\'m looking for...', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Choose what kind of connections you want', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        Row(children: [
          _MatchTypeCard(label: '✈️ Travel Buddy', subtitle: 'Find companions for trips', value: 'buddy',
            selected: _matchType == 'buddy', onTap: () => setState(() => _matchType = 'buddy')),
          const SizedBox(width: 10),
          _MatchTypeCard(label: '💑 Dating', subtitle: 'Meet someone special', value: 'dating',
            selected: _matchType == 'dating', onTap: () => setState(() => _matchType = 'dating')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _MatchTypeCard(label: '🎒 Solo', subtitle: 'Solo adventure partner', value: 'solo',
            selected: _matchType == 'solo', onTap: () => setState(() => _matchType = 'solo')),
          const SizedBox(width: 10),
          _MatchTypeCard(label: '🌍 All Types', subtitle: 'Open to everything', value: 'all',
            selected: _matchType == 'all', onTap: () => setState(() => _matchType = 'all')),
        ]),
        const SizedBox(height: 28),
        // Hobbies
        Row(children: [
          const Text('Hobbies & Interests', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${_selectedHobbies.length}/10 selected', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        const Text('Select up to 10 interests to show on your profile', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: _allHobbies.map((h) {
          final selected = _selectedHobbies.contains(h);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (selected) {
                  _selectedHobbies.remove(h);
                } else if (_selectedHobbies.length < 10) {
                  _selectedHobbies.add(h);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.dark : Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: selected ? AppColors.dark : Colors.grey.shade300, width: 1.5)),
              child: Text(h, style: TextStyle(
                color: selected ? AppColors.primary : Colors.black87,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal, fontSize: 14))));
        }).toList()),
        const SizedBox(height: 40),
      ])),
    );
  }
}

class _MatchTypeCard extends StatelessWidget {
  final String label, subtitle, value;
  final bool selected;
  final VoidCallback onTap;
  const _MatchTypeCard({required this.label, required this.subtitle, required this.value,
    required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AppColors.dark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppColors.dark : Colors.grey.shade200, width: selected ? 0 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
          color: selected ? AppColors.primary : Colors.black)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 11, color: selected ? Colors.white60 : Colors.grey)),
      ]))));
}
