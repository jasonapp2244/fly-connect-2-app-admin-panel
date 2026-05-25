import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/providers/trip_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/confirm_dialog.dart';

class TripsScreen extends StatelessWidget {
  /// Optional: if non-null and different from the current user's uid,
  /// the screen shows a read-only view of that user's passport.
  final String? userId;
  const TripsScreen({super.key, this.userId});

  static const List<Map<String, String>> _countries = [
    {'code': 'US', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': 'GB', 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': 'JP', 'name': 'Japan', 'flag': '🇯🇵'},
    {'code': 'FR', 'name': 'France', 'flag': '🇫🇷'},
    {'code': 'DE', 'name': 'Germany', 'flag': '🇩🇪'},
    {'code': 'AU', 'name': 'Australia', 'flag': '🇦🇺'},
    {'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦'},
    {'code': 'IT', 'name': 'Italy', 'flag': '🇮🇹'},
    {'code': 'ES', 'name': 'Spain', 'flag': '🇪🇸'},
    {'code': 'TH', 'name': 'Thailand', 'flag': '🇹🇭'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('My Trips', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () => _showAddTrip(context)),
        ],
      ),
      body: Consumer<TripProvider>(
        builder: (context, provider, _) {
          final trips = provider.trips;
          if (trips.isEmpty) return _emptyState(context);
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _passportSection(trips)),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (context, i) => _tripCard(context, trips[i], provider),
                childCount: trips.length,
              )),
            ),
          ]);
        },
      ),
    );
  }

  Widget _passportSection(List<TripModel> trips) {
    final stamps = trips.map((t) => t.countryCode).toSet();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.dark, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.book, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Digital Passport', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
            child: Text('${stamps.length} countries', style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: trips.map((t) {
          final country = _countries.firstWhere((c) => c['code'] == t.countryCode,
            orElse: () => {'code': t.countryCode, 'name': t.destination, 'flag': '✈️'});
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5))),
            child: Column(children: [
              Text(country['flag'] ?? '✈️', style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 2),
              Text(country['code'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 10)),
            ]));
        }).toList()),
      ]),
    );
  }

  Widget _tripCard(BuildContext context, TripModel trip, TripProvider provider) {
    final country = _countries.firstWhere((c) => c['code'] == trip.countryCode,
      orElse: () => {'code': trip.countryCode, 'name': trip.destination, 'flag': '✈️'});
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(width: 50, height: 50, decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(country['flag'] ?? '✈️', style: const TextStyle(fontSize: 26)))),
        title: Text(trip.destination, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(country['name'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(DateFormat('MMM d, yyyy').format(trip.startDate), style: const TextStyle(fontSize: 12)),
        ]),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final confirmed = await showConfirmDialog(
              context,
              title: 'Delete trip?',
              message: 'Delete your trip to ${trip.destination}? This cannot be undone.',
              confirmLabel: 'Delete',
              isDestructive: true,
            );
            if (!confirmed) return;
            try {
              await provider.deleteTrip(trip.id);
            } catch (_) {
              messenger.showSnackBar(const SnackBar(
                content: Text('Could not delete trip. Please try again.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ));
            }
          }),
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('✈️', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      const Text('No trips yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Add your first trip to start your digital passport',
        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 24),
      PrimaryButton(label: 'Add Trip', width: 160, onTap: () => _showAddTrip(context)),
    ]));

  void _showAddTrip(BuildContext context) {
    String? selectedCountry;
    final destCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Trip', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            AppTextField(hint: 'Destination', controller: destCtrl),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedCountry,
              hint: const Text('Select Country'),
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: _countries.map((c) => DropdownMenuItem(value: c['code'], child: Text('${c['flag']} ${c['name']}'))).toList(),
              onChanged: (v) => setState(() => selectedCountry = v),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Save Trip', onTap: () async {
              if (destCtrl.text.isEmpty || selectedCountry == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Please enter a destination and pick a country.'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              final auth = context.read<AuthProvider>();
              final uid = auth.currentUser?.uid;
              if (uid == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Please sign in to save trips.'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              final messenger = ScaffoldMessenger.of(ctx);
              try {
                await context.read<TripProvider>().addTrip(TripModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  userId: uid,
                  destination: destCtrl.text.trim(),
                  countryCode: selectedCountry!,
                  startDate: DateTime.now(),
                  createdAt: DateTime.now(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {
                messenger.showSnackBar(const SnackBar(
                  content: Text('Could not add trip. Please try again.'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            }),
          ]),
        )));
  }
}
