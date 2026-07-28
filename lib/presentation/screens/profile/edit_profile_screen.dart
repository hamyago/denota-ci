// lib/presentation/screens/profile/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../main.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _repo      = ProfileRepository();
  final _formKey   = GlobalKey<FormState>();
  final _picker    = ImagePicker();

  ProfileModel? _profile;
  AthleteProfileModel? _athleteProfile;
  bool _loading = true;
  bool _saving  = false;

  // Controllers
  final _nameCtrl    = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl     = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _clubCtrl    = TextEditingController();
  final _igCtrl      = TextEditingController();
  final _ttCtrl      = TextEditingController();
  final _ytCtrl      = TextEditingController();

  // Valeurs sélectionnées
  String? _gender;
  DateTime? _dateOfBirth;
  String? _level;
  String? _availability;
  String? _dominantFoot;
  double? _heightCm;
  double? _weightCm;
  int? _selectedSportId;
  int? _selectedPositionId;
  List<Map<String, dynamic>> _sports = [];
  List<Map<String, dynamic>> _positions = [];

  File? _avatarFile;
  File? _bannerFile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = supabase.auth.currentUser?.id ?? '';
    final results = await Future.wait([
      _repo.getProfile(uid),
      _repo.getAthleteProfile(uid),
      _repo.getSports(),
    ]);

    _profile        = results[0] as ProfileModel?;
    _athleteProfile = results[1] as AthleteProfileModel?;
    _sports         = results[2] as List<Map<String, dynamic>>;

    if (_profile != null) {
      _nameCtrl.text     = _profile!.fullName;
      _usernameCtrl.text = _profile!.username;
      _bioCtrl.text      = _profile!.bio ?? '';
      _cityCtrl.text     = _profile!.city ?? '';
      _gender            = _profile!.gender;
      _dateOfBirth       = _profile!.dateOfBirth;
    }

    if (_athleteProfile != null) {
      _clubCtrl.text      = _athleteProfile!.currentClub ?? '';
      _igCtrl.text        = _athleteProfile!.instagramUrl ?? '';
      _ttCtrl.text        = _athleteProfile!.tiktokUrl ?? '';
      _ytCtrl.text        = _athleteProfile!.youtubeUrl ?? '';
      _level              = _athleteProfile!.level;
      _availability       = _athleteProfile!.availability;
      _dominantFoot       = _athleteProfile!.dominantFoot;
      _heightCm           = _athleteProfile!.heightCm;
      _weightCm           = _athleteProfile!.weightKg;
      _selectedSportId    = _athleteProfile!.primarySportId;
      _selectedPositionId = _athleteProfile!.primaryPositionId;

      if (_selectedSportId != null) {
        _positions = await _repo.getPositions(_selectedSportId!);
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (file != null) setState(() => _avatarFile = File(file.path));
  }

  Future<void> _pickBanner() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
    if (file != null) setState(() => _bannerFile = File(file.path));
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1960),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _dateOfBirth = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // Upload avatar si changé
      String? avatarUrl;
      if (_avatarFile != null) {
        avatarUrl = await _repo.uploadAvatar(_avatarFile!);
      }

      // Upload banner si changé
      String? bannerUrl;
      if (_bannerFile != null) {
        bannerUrl = await _repo.uploadBanner(_bannerFile!);
      }

      // Mise à jour profil de base
      final profileData = {
        'full_name':    _nameCtrl.text.trim(),
        'username':     _usernameCtrl.text.trim(),
        'bio':          _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        'city':         _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'gender':       _gender,
        'date_of_birth': _dateOfBirth?.toIso8601String().split('T').first,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (bannerUrl != null) 'banner_url': bannerUrl,
      };
      await _repo.updateProfile(profileData);

      // Mise à jour profil athlète
      if (_profile?.role == 'athlete') {
        final athleteData = {
          'primary_sport_id':    _selectedSportId,
          'primary_position_id': _selectedPositionId,
          'current_club':        _clubCtrl.text.trim().isEmpty ? null : _clubCtrl.text.trim(),
          'level':               _level,
          'availability':        _availability,
          'dominant_foot':       _dominantFoot,
          'height_cm':           _heightCm,
          'weight_kg':           _weightCm,
          'instagram_url':       _igCtrl.text.trim().isEmpty ? null : _igCtrl.text.trim(),
          'tiktok_url':          _ttCtrl.text.trim().isEmpty ? null : _ttCtrl.text.trim(),
          'youtube_url':         _ytCtrl.text.trim().isEmpty ? null : _ytCtrl.text.trim(),
        };
        await _repo.upsertAthleteProfile(athleteData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour avec succès ✓'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _usernameCtrl.dispose(); _bioCtrl.dispose();
    _cityCtrl.dispose(); _clubCtrl.dispose(); _igCtrl.dispose();
    _ttCtrl.dispose(); _ytCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Text('Enregistrer', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            // ── Photo de couverture ────────────────────
            GestureDetector(
              onTap: _pickBanner,
              child: Container(
                height: 130,
                color: AppColors.primaryBg,
                child: _bannerFile != null
                    ? Image.file(_bannerFile!, fit: BoxFit.cover)
                    : _profile?.bannerUrl != null
                        ? Image.network(_profile!.bannerUrl!, fit: BoxFit.cover)
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28),
                                SizedBox(height: 4),
                                Text('Ajouter une bannière', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                              ],
                            ),
                          ),
              ),
            ),

            // ── Avatar ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Transform.translate(
                offset: const Offset(0, -40),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.white, width: 4),
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.primaryBg,
                              backgroundImage: _avatarFile != null
                                  ? FileImage(_avatarFile!)
                                  : (_profile?.avatarUrl != null
                                      ? NetworkImage(_profile!.avatarUrl!) as ImageProvider
                                      : null),
                              child: (_avatarFile == null && _profile?.avatarUrl == null)
                                  ? Text(
                                      _profile?.fullName.isNotEmpty == true ? _profile!.fullName[0] : '?',
                                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.primary),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Score de complétude
                    _ProfileCompletionIndicator(score: _profile?.profileScore ?? 0),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Infos de base ──────────────────────
                  _SectionHeader(title: 'Informations personnelles'),
                  const SizedBox(height: 12),

                  _buildField(_nameCtrl, 'Nom complet', Icons.person_outlined,
                      validator: (v) => (v?.isEmpty ?? true) ? 'Requis' : null),
                  const SizedBox(height: 12),

                  _buildField(_usernameCtrl, 'Nom d\'utilisateur', Icons.alternate_email,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Requis';
                        if (v!.contains(' ')) return 'Pas d\'espaces';
                        return null;
                      }),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _bioCtrl,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      hintText: 'Parlez de vous, de votre parcours...',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date de naissance
                  GestureDetector(
                    onTap: _selectDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Date de naissance',
                          prefixIcon: const Icon(Icons.cake_outlined),
                          hintText: _dateOfBirth != null
                              ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                              : 'Sélectionner',
                        ),
                        controller: TextEditingController(
                          text: _dateOfBirth != null
                              ? '${_dateOfBirth!.day.toString().padLeft(2,'0')}/${_dateOfBirth!.month.toString().padLeft(2,'0')}/${_dateOfBirth!.year}'
                              : '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Genre
                  _buildDropdown<String>(
                    value: _gender,
                    label: 'Genre',
                    icon: Icons.wc_outlined,
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Masculin')),
                      DropdownMenuItem(value: 'female', child: Text('Féminin')),
                      DropdownMenuItem(value: 'other', child: Text('Autre')),
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                  const SizedBox(height: 12),

                  _buildField(_cityCtrl, 'Ville', Icons.location_city_outlined),
                  const SizedBox(height: 24),

                  // ── Profil sportif (si athlète) ────────
                  if (_profile?.role == 'athlete') ...[
                    _SectionHeader(title: 'Profil sportif'),
                    const SizedBox(height: 12),

                    // Sport
                    _buildDropdown<int>(
                      value: _selectedSportId,
                      label: 'Sport principal',
                      icon: Icons.sports_outlined,
                      items: _sports.map((s) => DropdownMenuItem<int>(
                        value: s['id'] as int,
                        child: Text(s['name_fr'] as String),
                      )).toList(),
                      onChanged: (v) async {
                        setState(() { _selectedSportId = v; _selectedPositionId = null; _positions = []; });
                        if (v != null) {
                          final pos = await _repo.getPositions(v);
                          if (mounted) setState(() => _positions = pos);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Poste
                    if (_positions.isNotEmpty)
                      _buildDropdown<int>(
                        value: _selectedPositionId,
                        label: 'Poste / Spécialité',
                        icon: Icons.sports,
                        items: _positions.map((p) => DropdownMenuItem<int>(
                          value: p['id'] as int,
                          child: Text(p['name_fr'] as String),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedPositionId = v),
                      ),
                    if (_positions.isNotEmpty) const SizedBox(height: 12),

                    _buildField(_clubCtrl, 'Club / Équipe actuel(le)', Icons.home_outlined),
                    const SizedBox(height: 12),

                    // Niveau
                    _buildDropdown<String>(
                      value: _level,
                      label: 'Niveau',
                      icon: Icons.trending_up_outlined,
                      items: const [
                        DropdownMenuItem(value: 'amateur',      child: Text('Amateur')),
                        DropdownMenuItem(value: 'semi_pro',     child: Text('Semi-Professionnel')),
                        DropdownMenuItem(value: 'professional', child: Text('Professionnel')),
                      ],
                      onChanged: (v) => setState(() => _level = v),
                    ),
                    const SizedBox(height: 12),

                    // Disponibilité
                    _buildDropdown<String>(
                      value: _availability,
                      label: 'Disponibilité',
                      icon: Icons.access_time_outlined,
                      items: const [
                        DropdownMenuItem(value: 'immediate',     child: Text('Disponible immédiatement')),
                        DropdownMenuItem(value: '3_months',      child: Text('Dans 3 mois')),
                        DropdownMenuItem(value: '6_months',      child: Text('Dans 6 mois')),
                        DropdownMenuItem(value: 'not_available', child: Text('Non disponible')),
                      ],
                      onChanged: (v) => setState(() => _availability = v),
                    ),
                    const SizedBox(height: 12),

                    // Pied dominant
                    _buildDropdown<String>(
                      value: _dominantFoot,
                      label: 'Pied / Main dominant(e)',
                      icon: Icons.accessibility_new_outlined,
                      items: const [
                        DropdownMenuItem(value: 'right', child: Text('Droit(e)')),
                        DropdownMenuItem(value: 'left',  child: Text('Gauche')),
                        DropdownMenuItem(value: 'both',  child: Text('Les deux')),
                      ],
                      onChanged: (v) => setState(() => _dominantFoot = v),
                    ),
                    const SizedBox(height: 12),

                    // Taille & Poids
                    Row(children: [
                      Expanded(child: TextFormField(
                        initialValue: _heightCm?.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Taille (cm)', prefixIcon: Icon(Icons.height)),
                        onChanged: (v) => _heightCm = double.tryParse(v),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        initialValue: _weightCm?.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Poids (kg)', prefixIcon: Icon(Icons.monitor_weight_outlined)),
                        onChanged: (v) => _weightCm = double.tryParse(v),
                      )),
                    ]),
                    const SizedBox(height: 24),

                    // ── Réseaux sociaux ──────────────────
                    _SectionHeader(title: 'Réseaux sociaux'),
                    const SizedBox(height: 12),
                    _buildField(_igCtrl, 'Instagram', Icons.camera_alt_outlined,
                        hint: '@moncompte'),
                    const SizedBox(height: 12),
                    _buildField(_ttCtrl, 'TikTok', Icons.music_note_outlined,
                        hint: '@moncompte'),
                    const SizedBox(height: 12),
                    _buildField(_ytCtrl, 'YouTube', Icons.play_circle_outline,
                        hint: 'URL de la chaîne'),
                    const SizedBox(height: 32),
                  ],

                  // ── Bouton sauvegarder ─────────────────
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Enregistrer les modifications'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

// ── Indicateur de complétude ──────────────────────────────
class _ProfileCompletionIndicator extends StatelessWidget {
  final int score;
  const _ProfileCompletionIndicator({required this.score});

  Color get _color {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profil complété à $score%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.grey600)),
        const SizedBox(height: 6),
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: AppColors.grey200,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          score < 100 ? 'Complétez votre profil pour plus de visibilité' : 'Profil complet ! 🎉',
          style: const TextStyle(fontSize: 10, color: AppColors.grey400),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.grey200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.grey500)),
        ),
        Expanded(child: Divider(color: AppColors.grey200)),
      ],
    );
  }
}
