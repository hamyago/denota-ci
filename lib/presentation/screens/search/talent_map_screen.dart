// lib/presentation/screens/search/talent_map_screen.dart
//
// Carte des talents : affiche les athlètes géolocalisés sur une carte
// OpenStreetMap (flutter_map, sans clé API). Tap sur un marqueur -> fiche
// rapide + accès au profil.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../profile/profile_screen.dart';

class TalentMapScreen extends StatefulWidget {
  const TalentMapScreen({super.key});

  @override
  State<TalentMapScreen> createState() => _TalentMapScreenState();
}

class _TalentMapScreenState extends State<TalentMapScreen> {
  final MapController _map = MapController();
  List<Map<String, dynamic>> _athletes = [];
  bool _loading = true;
  String? _error;

  // Centre approximatif de la Côte d'Ivoire
  static const LatLng _center = LatLng(6.9, -5.3);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await supabase.rpc('athletes_on_map');
      final list = List<Map<String, dynamic>>.from(data as List);
      if (!mounted) return;
      setState(() { _athletes = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  void _openAthlete(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryBg,
                    backgroundImage: (a['avatar_url'] != null)
                        ? CachedNetworkImageProvider(a['avatar_url'] as String)
                        : null,
                    child: (a['avatar_url'] == null)
                        ? const Icon(Icons.person, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['full_name'] as String? ?? 'Athlète',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          [a['sport_name'], a['city']].where((e) => e != null && (e as String).isNotEmpty).join(' • '),
                          style: const TextStyle(fontSize: 13, color: AppColors.grey500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: a['id'] as String),
                    ));
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Voir le profil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des talents'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 48, color: AppColors.grey400),
              const SizedBox(height: 12),
              Text('Carte indisponible :\n$_error',
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey500)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final markers = <Marker>[];
    for (final a in _athletes) {
      final lat = _toDouble(a['lat']);
      final lng = _toDouble(a['lng']);
      if (lat == null || lng == null) continue;
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 48,
          height: 48,
          child: GestureDetector(
            onTap: () => _openAthlete(a),
            child: _MarkerPin(avatarUrl: a['avatar_url'] as String?),
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: const MapOptions(
            initialCenter: _center,
            initialZoom: 6.6,
            minZoom: 4,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.oyopmt.denota',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        // Compteur en bas
        Positioned(
          left: 12, bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
            ),
            child: Text(
              '${markers.length} talent${markers.length > 1 ? 's' : ''} sur la carte',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ),
        if (markers.isEmpty)
          const Center(
            child: Card(
              margin: EdgeInsets.all(32),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Aucun athlète géolocalisé pour l\'instant.\nLes athlètes apparaissent ici dès qu\'ils renseignent leur ville.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MarkerPin extends StatelessWidget {
  final String? avatarUrl;
  const _MarkerPin({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 3),
        color: AppColors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4)],
      ),
      child: ClipOval(
        child: (avatarUrl != null)
            ? CachedNetworkImage(imageUrl: avatarUrl!, fit: BoxFit.cover)
            : const Icon(Icons.person, color: AppColors.primary, size: 22),
      ),
    );
  }
}
