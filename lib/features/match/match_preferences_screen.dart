import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/constants/app_colors.dart';

class MatchPreferencesScreen extends StatefulWidget {
  const MatchPreferencesScreen({super.key});
  @override State<MatchPreferencesScreen> createState() => _MatchPreferencesScreenState();
}

class _MatchPreferencesScreenState extends State<MatchPreferencesScreen> {
  double _maxDistance = 50;
  RangeValues _ageRange = const RangeValues(22, 45);
  bool _sameAirline = false;
  bool _verifiedOnly = false;
  final List<String> _selectedAirlines = [];
  final List<String> _selectedPositions = [];

  static const _airlines = ['Delta', 'United', 'American', 'Southwest', 'JetBlue', 'Alaska', 'Spirit'];
  static const _positions = ['Pilot', 'Flight Attendant', 'Gate Agent', 'Ground Crew', 'TSA'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Match Preferences', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            // Save sits on a white AppBar — primary fails AA. Use dark.
            child: const Text('Save', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold, fontSize: 16))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // Distance
        const _SectionTitle('Maximum Distance'),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Range', style: TextStyle(color: Colors.grey, fontSize: 13)),
          Text('${_maxDistance.toInt()} km', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.dark, thumbColor: AppColors.primary,
            inactiveTrackColor: Colors.grey.shade200, overlayColor: AppColors.primary.withValues(alpha: 0.2)),
          child: Slider(value: _maxDistance, min: 5, max: 200, divisions: 39,
            onChanged: (v) => setState(() => _maxDistance = v))),
        const SizedBox(height: 20),
        // Age range
        const _SectionTitle('Age Range'),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Range', style: TextStyle(color: Colors.grey, fontSize: 13)),
          Text('${_ageRange.start.toInt()}–${_ageRange.end.toInt()} yrs',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.dark, thumbColor: AppColors.primary,
            inactiveTrackColor: Colors.grey.shade200, overlayColor: AppColors.primary.withValues(alpha: 0.2)),
          child: RangeSlider(values: _ageRange, min: 18, max: 65, divisions: 47,
            onChanged: (v) => setState(() => _ageRange = v))),
        const SizedBox(height: 20),
        // Toggle filters
        const _SectionTitle('Filters'),
        const SizedBox(height: 8),
        _ToggleTile(label: 'Same airline only', subtitle: 'Only show people from my airline',
          value: _sameAirline, onChanged: (v) => setState(() => _sameAirline = v)),
        _ToggleTile(label: 'Verified profiles only', subtitle: 'Only show employee-verified accounts',
          value: _verifiedOnly, onChanged: (v) => setState(() => _verifiedOnly = v)),
        const SizedBox(height: 20),
        // Airline filter
        const _SectionTitle('Airlines'),
        const SizedBox(height: 8),
        const Text('Show people from specific airlines', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _airlines.map((a) {
          final sel = _selectedAirlines.contains(a);
          return FilterChip(label: Text(a),
            selected: sel,
            onSelected: (_) => setState(() => sel ? _selectedAirlines.remove(a) : _selectedAirlines.add(a)),
            selectedColor: AppColors.primary,
            checkmarkColor: AppColors.dark,
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)));
        }).toList()),
        const SizedBox(height: 20),
        // Position filter
        const _SectionTitle('Positions'),
        const SizedBox(height: 8),
        const Text('Show people with specific job roles', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _positions.map((p) {
          final sel = _selectedPositions.contains(p);
          return FilterChip(label: Text(p),
            selected: sel,
            onSelected: (_) => setState(() => sel ? _selectedPositions.remove(p) : _selectedPositions.add(p)),
            selectedColor: AppColors.primary,
            checkmarkColor: AppColors.dark,
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)));
        }).toList()),
        const SizedBox(height: 40),
        OutlinedButton(
          onPressed: () => setState(() {
            _maxDistance = 50; _ageRange = const RangeValues(22, 45);
            _sameAirline = false; _verifiedOnly = false;
            _selectedAirlines.clear(); _selectedPositions.clear();
          }),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('Reset Filters')),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black));
}

class _ToggleTile extends StatelessWidget {
  final String label, subtitle; final bool value; final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.label, required this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ])),
      CupertinoSwitch(value: value, activeTrackColor: AppColors.dark, onChanged: onChanged),
    ]));
}
