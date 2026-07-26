// lib/presentation/widgets/search/filter_sheet.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/search_repository.dart';

class FilterSheet extends StatefulWidget {
  final SearchFilters current;
  final List<Map<String, dynamic>> sports;
  final Future<List<Map<String, dynamic>>> Function(int) getPositions;
  final Future<List<Map<String, dynamic>>> Function() getCities;

  const FilterSheet({
    super.key,
    required this.current,
    required this.sports,
    required this.getPositions,
    required this.getCities,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late SearchFilters _filters;
  List<Map<String, dynamic>> _positions = [];
  List<Map<String, dynamic>> _cities    = [];
  bool _loadingPositions = false;
  bool _loadingCities    = false;

  @override
  void initState() {
    super.initState();
    _filters = widget.current;
    if (_filters.sportId != null) _loadPositions(_filters.sportId!);
    _loadCities();
  }

  Future<void> _loadPositions(int sportId) async {
    setState(() => _loadingPositions = true);
    final pos = await widget.getPositions(sportId);
    if (mounted) setState(() { _positions = pos; _loadingPositions = false; });
  }

  Future<void> _loadCities() async {
    setState(() => _loadingCities = true);
    final cities = await widget.getCities();
    if (mounted) setState(() { _cities = cities; _loadingCities = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const Text('Filtres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  if (_filters.activeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text('${_filters.activeCount}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _filters = const SearchFilters()),
                    child: const Text('Réinitialiser', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.grey200),

            // Contenu scrollable
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [

                  // ── Sport ──────────────────────────────
                  _FilterSection(title: 'Sport', icon: Icons.sports_outlined),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: widget.sports.map((s) {
                      final id       = s['id'] as int;
                      final name     = s['name_fr'] as String;
                      final selected = _filters.sportId == id;
                      return FilterChip(
                        label: Text(name),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _filters = selected
                                ? _filters.copyWith(clearSport: true, clearPosition: true)
                                : _filters.copyWith(sportId: id, clearPosition: true);
                            _positions = [];
                          });
                          if (!selected) _loadPositions(id);
                        },
                        selectedColor: AppColors.primaryBg,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.primary : AppColors.grey600,
                          fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        side: BorderSide(color: selected ? AppColors.primary : AppColors.grey200),
                      );
                    }).toList(),
                  ),

                  // ── Poste (si sport sélectionné) ───────
                  if (_filters.sportId != null) ...[
                    const SizedBox(height: 20),
                    _FilterSection(title: 'Poste / Spécialité', icon: Icons.sports),
                    const SizedBox(height: 10),
                    _loadingPositions
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        : Wrap(
                            spacing: 8, runSpacing: 8,
                            children: _positions.map((p) {
                              final id       = p['id'] as int;
                              final name     = p['name_fr'] as String;
                              final selected = _filters.positionId == id;
                              return FilterChip(
                                label: Text(name),
                                selected: selected,
                                onSelected: (_) => setState(() {
                                  _filters = selected
                                      ? _filters.copyWith(clearPosition: true)
                                      : _filters.copyWith(positionId: id);
                                }),
                                selectedColor: AppColors.primaryBg,
                                checkmarkColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: selected ? AppColors.primary : AppColors.grey600,
                                  fontSize: 12,
                                ),
                                side: BorderSide(color: selected ? AppColors.primary : AppColors.grey200),
                              );
                            }).toList(),
                          ),
                  ],

                  // ── Niveau ─────────────────────────────
                  const SizedBox(height: 20),
                  _FilterSection(title: 'Niveau', icon: Icons.trending_up_outlined),
                  const SizedBox(height: 10),
                  Row(children: [
                    'amateur', 'semi_pro', 'professional',
                  ].map((l) {
                    final labels = {'amateur': '🌱 Amateur', 'semi_pro': '⭐ Semi-Pro', 'professional': '🏆 Pro'};
                    final selected = _filters.level == l;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _filters = selected
                              ? _filters.copyWith(clearLevel: true)
                              : _filters.copyWith(level: l);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primaryBg : AppColors.grey100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
                          ),
                          child: Text(labels[l]!, textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  color: selected ? AppColors.primary : AppColors.grey600)),
                        ),
                      ),
                    );
                  }).toList()),

                  // ── Disponibilité ──────────────────────
                  const SizedBox(height: 20),
                  _FilterSection(title: 'Disponibilité', icon: Icons.access_time_outlined),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: {
                      'immediate':     '🟢 Immédiatement',
                      '3_months':      '🟡 Dans 3 mois',
                      '6_months':      '🟠 Dans 6 mois',
                      'not_available': '🔴 Non dispo',
                    }.entries.map((e) {
                      final selected = _filters.availability == e.key;
                      return FilterChip(
                        label: Text(e.value),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _filters = selected
                              ? _filters.copyWith(clearAvailability: true)
                              : _filters.copyWith(availability: e.key);
                        }),
                        selectedColor: AppColors.primaryBg,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(color: selected ? AppColors.primary : AppColors.grey600, fontSize: 12),
                        side: BorderSide(color: selected ? AppColors.primary : AppColors.grey200),
                      );
                    }).toList(),
                  ),

                  // ── Ville ──────────────────────────────
                  const SizedBox(height: 20),
                  _FilterSection(title: 'Ville', icon: Icons.location_city_outlined),
                  const SizedBox(height: 10),
                  _loadingCities
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _cities.take(12).map((c) {
                            final name     = c['name'] as String;
                            final isMajor  = c['is_major'] as bool? ?? false;
                            final selected = _filters.city == name;
                            return FilterChip(
                              label: Text('${isMajor ? "📍" : ""} $name'.trim()),
                              selected: selected,
                              onSelected: (_) => setState(() {
                                _filters = selected
                                    ? _filters.copyWith(clearCity: true)
                                    : _filters.copyWith(city: name);
                              }),
                              selectedColor: AppColors.primaryBg,
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: selected ? AppColors.primary : AppColors.grey600,
                                fontSize: 12, fontWeight: isMajor ? FontWeight.w500 : FontWeight.w400,
                              ),
                              side: BorderSide(color: selected ? AppColors.primary : AppColors.grey200),
                            );
                          }).toList(),
                        ),

                  // ── Tranche d'âge ──────────────────────
                  const SizedBox(height: 20),
                  _FilterSection(title: 'Tranche d\'âge', icon: Icons.cake_outlined),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _AgeSelector(
                        label: 'Min',
                        value: _filters.ageMin,
                        min: 8, max: 50,
                        onChanged: (v) => setState(() => _filters = _filters.copyWith(ageMin: v)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text('—', style: TextStyle(color: AppColors.grey400)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _AgeSelector(
                        label: 'Max',
                        value: _filters.ageMax,
                        min: 8, max: 50,
                        onChanged: (v) => setState(() => _filters = _filters.copyWith(ageMax: v)),
                      ),
                    ),
                  ]),

                  // ── Talent Score minimum ───────────────
                  const SizedBox(height: 20),
                  _FilterSection(title: 'Talent Score™ minimum', icon: Icons.star_outlined),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: Slider(
                        value: _filters.scoreMin ?? 0,
                        min: 0, max: 100, divisions: 20,
                        activeColor: AppColors.accent,
                        inactiveColor: AppColors.grey200,
                        label: '${(_filters.scoreMin ?? 0).toStringAsFixed(0)}',
                        onChanged: (v) => setState(() => _filters = _filters.copyWith(scoreMin: v == 0 ? null : v)),
                      ),
                    ),
                    Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${(_filters.scoreMin ?? 0).toStringAsFixed(0)}+',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accentDark),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 32),
                ],
              ),
            ),

            // ── Bouton appliquer ───────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _filters),
                  child: Text(
                    _filters.activeCount > 0
                        ? 'Appliquer ${_filters.activeCount} filtre${_filters.activeCount > 1 ? "s" : ""}'
                        : 'Appliquer',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final IconData icon;
  const _FilterSection({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
    ]);
  }
}

class _AgeSelector extends StatelessWidget {
  final String label;
  final int? value;
  final int min, max;
  final void Function(int?) onChanged;

  const _AgeSelector({required this.label, this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('—')),
        ...List.generate(max - min + 1, (i) => min + i)
            .map((v) => DropdownMenuItem(value: v, child: Text('$v ans'))),
      ],
      onChanged: onChanged,
    );
  }
}
