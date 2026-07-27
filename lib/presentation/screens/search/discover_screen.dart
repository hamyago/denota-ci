// lib/presentation/screens/search/discover_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../profile/profile_screen.dart';
import '../../../data/repositories/search_repository.dart';
import '../../../data/repositories/recruiter_repository.dart';
import '../../widgets/search/filter_sheet.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  final _searchRepo    = SearchRepository();
  final _recruiterRepo = RecruiterRepository();
  final _searchCtrl    = TextEditingController();
  final _scrollCtrl    = ScrollController();

  late TabController _viewTabs;

  SearchFilters _filters  = const SearchFilters();
  List<Map<String, dynamic>> _results      = [];
  List<Map<String, dynamic>> _suggestions  = [];
  List<Map<String, dynamic>> _sports       = [];
  bool _loading         = false;
  bool _loadingMore     = false;
  bool _hasMore         = true;
  bool _showSuggestions = false;
  String _lastQuery     = '';
  Timer? _debounce;

  // Favoris locaux (pour réactivité UI)
  final Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _viewTabs = TabController(length: 2, vsync: this);
    _loadInitial();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _viewTabs.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    final sports = await _searchRepo.getSports();
    final results = await _searchRepo.searchAthletes(_filters);
    if (!mounted) return;
    setState(() { _sports = sports; _results = results; _loading = false; });
  }

  Future<void> _search() async {
    setState(() { _loading = true; _results = []; _hasMore = true; });
    final q = _searchCtrl.text.trim();
    List<Map<String, dynamic>> results;
    if (q.isNotEmpty) {
      results = await _searchRepo.fullTextSearch(q);
    } else {
      results = await _searchRepo.searchAthletes(_filters);
    }
    if (!mounted) return;
    setState(() { _results = results; _loading = false; _hasMore = results.length >= _filters.limit; });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final more = await _searchRepo.searchAthletes(
      _filters.copyWith(offset: _results.length),
    );
    if (!mounted) return;
    setState(() {
      _results.addAll(more);
      _hasMore = more.length >= _filters.limit;
      _loadingMore = false;
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() => _showSuggestions = false);
      _search();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (q == _lastQuery) return;
      _lastQuery = q;
      final sug = await _searchRepo.getSearchSuggestions(q);
      if (mounted) setState(() { _suggestions = sug.map((s) => {'name': s}).toList(); _showSuggestions = sug.isNotEmpty; });
    });
  }

  Future<void> _openFilters() async {
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterSheet(
        current: _filters,
        sports: _sports,
        getPositions: _searchRepo.getPositions,
        getCities: _searchRepo.getCities,
      ),
    );
    if (newFilters != null) {
      setState(() => _filters = newFilters);
      _search();
    }
  }

  Future<void> _toggleFavorite(String athleteId) async {
    final isFav = _favoriteIds.contains(athleteId);
    setState(() => isFav ? _favoriteIds.remove(athleteId) : _favoriteIds.add(athleteId));
    try {
      if (isFav) {
        await _recruiterRepo.removeFavorite(athleteId);
      } else {
        await _recruiterRepo.addFavorite(athleteId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Ajouté aux favoris'), backgroundColor: AppColors.success, duration: Duration(seconds: 2)),
          );
        }
      }
    } catch (_) {
      setState(() => isFav ? _favoriteIds.add(athleteId) : _favoriteIds.remove(athleteId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Découvrir'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: TabBar(
            controller: _viewTabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.grey400,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(icon: Icon(Icons.view_list_outlined), text: 'Liste'),
              Tab(icon: Icon(Icons.grid_view_outlined), text: 'Grille'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Barre de recherche ───────────────────────
          _SearchBar(
            controller: _searchCtrl,
            filters: _filters,
            onChanged: _onSearchChanged,
            onSubmitted: (_) { setState(() => _showSuggestions = false); _search(); },
            onClear: () { _searchCtrl.clear(); setState(() => _showSuggestions = false); _search(); },
            onFilterTap: _openFilters,
          ),

          // ── Filtres actifs (chips) ───────────────────
          if (_filters.hasActiveFilters)
            _ActiveFiltersBar(filters: _filters, sports: _sports, onClear: () { setState(() => _filters = const SearchFilters()); _search(); }),

          // ── Suggestions autocomplete ─────────────────
          if (_showSuggestions)
            _SuggestionsDropdown(
              suggestions: _suggestions,
              onSelect: (name) {
                _searchCtrl.text = name;
                setState(() => _showSuggestions = false);
                _search();
              },
            ),

          // ── Résultats ────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _results.isEmpty
                    ? _EmptyState(hasFilters: _filters.hasActiveFilters || _searchCtrl.text.isNotEmpty)
                    : Column(
                        children: [
                          _ResultsHeader(count: _results.length, hasMore: _hasMore),
                          Expanded(
                            child: TabBarView(
                              controller: _viewTabs,
                              children: [
                                // Liste
                                _ListView(
                                  results:      _results,
                                  scrollCtrl:   _scrollCtrl,
                                  loadingMore:  _loadingMore,
                                  favoriteIds:  _favoriteIds,
                                  onTap:        (id) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: id))),
                                  onFavorite:   _toggleFavorite,
                                ),
                                // Grille
                                _GridView(
                                  results:     _results,
                                  favoriteIds: _favoriteIds,
                                  onTap:       (id) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: id))),
                                  onFavorite:  _toggleFavorite,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Barre de recherche ────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final SearchFilters filters;
  final void Function(String) onChanged;
  final void Function(String) onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onFilterTap;

  const _SearchBar({
    required this.controller,
    required this.filters,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Nom, sport, ville...',
                prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.grey400), onPressed: onClear)
                    : null,
                filled: true,
                fillColor: AppColors.grey100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Bouton filtres
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: onFilterTap,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: filters.hasActiveFilters ? AppColors.primary : AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.tune_outlined,
                      color: filters.hasActiveFilters ? Colors.white : AppColors.grey500, size: 22),
                ),
              ),
              if (filters.activeCount > 0)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    child: Center(
                      child: Text('${filters.activeCount}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filtres actifs ────────────────────────────────────────
class _ActiveFiltersBar extends StatelessWidget {
  final SearchFilters filters;
  final List<Map<String, dynamic>> sports;
  final VoidCallback onClear;

  const _ActiveFiltersBar({required this.filters, required this.sports, required this.onClear});

  String? _sportName(int? id) {
    if (id == null) return null;
    return sports.firstWhere((s) => s['id'] == id, orElse: () => {})['name_fr'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final chips = <String>[];
    if (filters.sportId != null && _sportName(filters.sportId) != null) {
      chips.add(_sportName(filters.sportId)!);
    }
    if (filters.level != null) {
      chips.add({'amateur': 'Amateur', 'semi_pro': 'Semi-Pro', 'professional': 'Pro'}[filters.level] ?? filters.level!);
    }
    if (filters.city != null) { chips.add(filters.city!); }
    if (filters.ageMin != null || filters.ageMax != null) {
      chips.add('${filters.ageMin ?? "?"}–${filters.ageMax ?? "?"} ans');
    }
    if (filters.scoreMin != null && filters.scoreMin! > 0) {
      chips.add('Score ≥ ${filters.scoreMin!.toStringAsFixed(0)}');
    }
    if (filters.availability != null) {
      chips.add({'immediate': 'Dispo maintenant', '3_months': '3 mois', '6_months': '6 mois'}[filters.availability] ?? '');
    }

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips.map((c) => Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(c, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                )).toList(),
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Effacer', style: TextStyle(color: AppColors.error, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Suggestions dropdown ─────────────────────────────────
class _SuggestionsDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> suggestions;
  final void Function(String) onSelect;

  const _SuggestionsDropdown({required this.suggestions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.grey200)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (_, i) => ListTile(
          dense: true,
          leading: const Icon(Icons.search, size: 16, color: AppColors.grey400),
          title: Text(suggestions[i]['name'] as String, style: const TextStyle(fontSize: 14)),
          onTap: () => onSelect(suggestions[i]['name'] as String),
        ),
      ),
    );
  }
}

// ── Header résultats ──────────────────────────────────────
class _ResultsHeader extends StatelessWidget {
  final int count;
  final bool hasMore;
  const _ResultsHeader({required this.count, required this.hasMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            hasMore ? '$count+ talents trouvés' : '$count talent${count > 1 ? "s" : ""} trouvé${count > 1 ? "s" : ""}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.grey500),
          ),
          const Spacer(),
          const Text('Trié par score', style: TextStyle(fontSize: 12, color: AppColors.grey400)),
          const Icon(Icons.arrow_drop_down, color: AppColors.grey400, size: 18),
        ],
      ),
    );
  }
}

// ── Vue Liste ─────────────────────────────────────────────
class _ListView extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final ScrollController scrollCtrl;
  final bool loadingMore;
  final Set<String> favoriteIds;
  final void Function(String) onTap;
  final void Function(String) onFavorite;

  const _ListView({
    required this.results, required this.scrollCtrl, required this.loadingMore,
    required this.favoriteIds, required this.onTap, required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: results.length + (loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == results.length) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          ));
        }
        final t = results[i];
        final id = t['id'] as String;
        return _AthleteListCard(
          talent:   t,
          isFav:    favoriteIds.contains(id),
          onTap:    () => onTap(id),
          onFav:    () => onFavorite(id),
          rank:     i + 1,
        );
      },
    );
  }
}

// ── Vue Grille ────────────────────────────────────────────
class _GridView extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final Set<String> favoriteIds;
  final void Function(String) onTap;
  final void Function(String) onFavorite;

  const _GridView({required this.results, required this.favoriteIds, required this.onTap, required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72,
      ),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final t  = results[i];
        final id = t['id'] as String;
        return _AthleteGridCard(
          talent:  t,
          isFav:   favoriteIds.contains(id),
          rank:    i + 1,
          onTap:   () => onTap(id),
          onFav:   () => onFavorite(id),
        );
      },
    );
  }
}

// ── Card Liste ────────────────────────────────────────────
class _AthleteListCard extends StatelessWidget {
  final Map<String, dynamic> talent;
  final bool isFav;
  final VoidCallback onTap;
  final VoidCallback onFav;
  final int rank;

  const _AthleteListCard({required this.talent, required this.isFav, required this.onTap, required this.onFav, required this.rank});

  @override
  Widget build(BuildContext context) {
    final name     = talent['full_name'] as String? ?? '';
    final avatar   = talent['avatar_url'] as String?;
    final city     = talent['city'] as String?;
    final sport    = talent['sport_name'] as String?;
    final position = talent['position_name'] as String?;
    final score    = (talent['talent_score'] as num?)?.toDouble() ?? 0;
    final level    = talent['level'] as String?;
    final kyc      = talent['kyc_level'] as String?;
    final isMinor  = talent['is_minor'] as bool? ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            // Rang
            SizedBox(
              width: 28,
              child: Text('#$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.grey300)),
            ),

            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primaryBg,
              backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
              child: avatar == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16))
                  : null,
            ),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.ink), overflow: TextOverflow.ellipsis)),
                    if (kyc != null && kyc != 'none' && kyc != 'email') ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.verified, color: AppColors.primary, size: 13),
                    ],
                    if (isMinor) ...[
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(4)),
                        child: const Text('-18', style: TextStyle(fontSize: 9, color: AppColors.warning, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                  Text(
                    [if (sport != null) sport, if (position != null) position].join(' · '),
                    style: const TextStyle(fontSize: 12, color: AppColors.grey500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (city != null || level != null)
                    Text(
                      [if (city != null) '📍 $city', if (level != null) _levelEmoji(level)].join('  '),
                      style: const TextStyle(fontSize: 11, color: AppColors.grey400),
                    ),
                ],
              ),
            ),

            // Score + favori
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(8)),
                  child: Text(score.toStringAsFixed(0), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accentDark)),
                ),
                const Text('Score', style: TextStyle(fontSize: 9, color: AppColors.grey400)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onFav,
                  child: Icon(
                    isFav ? Icons.bookmark : Icons.bookmark_border,
                    color: isFav ? AppColors.primary : AppColors.grey300,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _levelEmoji(String level) {
    switch (level) {
      case 'professional': return '🏆 Pro';
      case 'semi_pro':     return '⭐ Semi-Pro';
      default:             return '🌱 Amateur';
    }
  }
}

// ── Card Grille ───────────────────────────────────────────
class _AthleteGridCard extends StatelessWidget {
  final Map<String, dynamic> talent;
  final bool isFav;
  final int rank;
  final VoidCallback onTap;
  final VoidCallback onFav;

  const _AthleteGridCard({required this.talent, required this.isFav, required this.rank, required this.onTap, required this.onFav});

  @override
  Widget build(BuildContext context) {
    final name   = talent['full_name'] as String? ?? '';
    final avatar = talent['avatar_url'] as String?;
    final city   = talent['city'] as String?;
    final sport  = talent['sport_name'] as String?;
    final score  = (talent['talent_score'] as num?)?.toDouble() ?? 0;
    final kyc    = talent['kyc_level'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Column(
          children: [
            // Photo + rang + favori
            Expanded(
              child: Stack(
                children: [
                  // Photo
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: avatar != null
                        ? CachedNetworkImage(imageUrl: avatar, width: double.infinity, fit: BoxFit.cover)
                        : Container(
                            width: double.infinity,
                            color: AppColors.primaryBg,
                            child: Center(
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ),
                          ),
                  ),
                  // Rang
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                      child: Text('#$rank', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  // Favori
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: onFav,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isFav ? AppColors.primary : Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.bookmark : Icons.bookmark_border,
                          color: Colors.white, size: 14,
                        ),
                      ),
                    ),
                  ),
                  // Score
                  Positioned(
                    bottom: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                      child: Text('${score.toStringAsFixed(0)} ⭐',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),

            // Infos bas
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink),
                        overflow: TextOverflow.ellipsis)),
                    if (kyc != null && kyc != 'none' && kyc != 'email')
                      const Icon(Icons.verified, color: AppColors.primary, size: 12),
                  ]),
                  if (sport != null)
                    Text(sport, style: const TextStyle(fontSize: 11, color: AppColors.grey500), overflow: TextOverflow.ellipsis),
                  if (city != null)
                    Text('📍 $city', style: const TextStyle(fontSize: 10, color: AppColors.grey400), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(hasFilters ? Icons.filter_list_off : Icons.search_off, size: 56, color: AppColors.grey300),
          const SizedBox(height: 16),
          Text(hasFilters ? 'Aucun talent correspond aux filtres' : 'Aucun résultat',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey500)),
          const SizedBox(height: 8),
          Text(hasFilters ? 'Essayez d\'élargir vos critères de recherche.' : 'Lancez une recherche ou explorez les talents.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.grey400)),
        ],
      ),
    );
  }
}
