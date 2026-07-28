// lib/presentation/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        data: {'full_name': _nameCtrl.text.trim()},
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Erreur lors de l\'inscription. Réessaie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700),
            children: [
              TextSpan(text: 'De', style: TextStyle(color: AppColors.ink)),
              TextSpan(text: 'No', style: TextStyle(color: AppColors.primary)),
              TextSpan(text: 'Ta', style: TextStyle(color: AppColors.accent)),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                const Text('Créer un compte', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 6),
                const Text('Rejoins la communauté DeNoTa CI', style: TextStyle(fontSize: 14, color: AppColors.grey500)),
                const SizedBox(height: 32),

                // Étapes
                _StepIndicator(current: 1, total: 2),
                const SizedBox(height: 24),

                if (_error != null)
                  _ErrorBanner(message: _error!),

                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Nom requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Email requis';
                    if (!(v!.contains('@'))) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Mot de passe requis';
                    if (v!.length < 8) return 'Minimum 8 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'En créant un compte, tu acceptes nos Conditions d\'utilisation et notre Politique de confidentialité.',
                  style: TextStyle(fontSize: 12, color: AppColors.grey400, height: 1.5),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Continuer →'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Déjà un compte ? ', style: TextStyle(color: AppColors.grey500, fontSize: 14)),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        child: const Text('Se connecter', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Choix du rôle ──────────────────────────────────────────
class RegisterRoleScreen extends StatefulWidget {
  const RegisterRoleScreen({super.key});
  @override
  State<RegisterRoleScreen> createState() => _RegisterRoleScreenState();
}

class _RegisterRoleScreenState extends State<RegisterRoleScreen> {
  String? _role;
  bool _loading = false;

  final _roles = const [
    _RoleOption(value: 'athlete',     emoji: '🏃', label: 'Sportif',            desc: 'Je suis un athlète qui cherche à être détecté'),
    _RoleOption(value: 'institution', emoji: '🏫', label: 'École / Club',        desc: 'Je représente un club, une école ou une académie'),
    _RoleOption(value: 'recruiter',   emoji: '🔍', label: 'Recruteur / Agent',   desc: 'Je recherche des talents pour un club ou en tant qu\'agent'),
    _RoleOption(value: 'sponsor',     emoji: '💰', label: 'Sponsor / Marque',    desc: 'Je cherche des sportifs ambassadeurs pour ma marque'),
  ];

  Future<void> _save() async {
    if (_role == null) return;
    setState(() => _loading = true);
    try {
      await supabase.from('profiles').update({'role': _role}).eq('id', supabase.auth.currentUser!.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Text('Tu es...', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 8),
              const Text('Choisis ton profil pour personnaliser ton expérience DeNoTa.', style: TextStyle(fontSize: 14, color: AppColors.grey500, height: 1.5)),
              const SizedBox(height: 8),
              _StepIndicator(current: 2, total: 2),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: _roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final r = _roles[i];
                    final selected = _role == r.value;
                    return GestureDetector(
                      onTap: () => setState(() => _role = r.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primaryBg : AppColors.grey100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? AppColors.primary : AppColors.grey200,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(r.emoji, style: const TextStyle(fontSize: 32)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.ink)),
                                  const SizedBox(height: 2),
                                  Text(r.desc, style: const TextStyle(fontSize: 13, color: AppColors.grey500, height: 1.4)),
                                ],
                              ),
                            ),
                            if (selected) const Icon(Icons.check_circle, color: AppColors.primary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_role == null || _loading) ? null : _save,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Commencer avec DeNoTa'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── OTP Screen ─────────────────────────────────────────────
class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes  = List.generate(6, (_) => FocusNode());
  bool _loading = false;

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) return;
    setState(() => _loading = true);
    try {
      await supabase.auth.verifyOTP(
        phone: widget.phone,
        token: _otp,
        type: OtpType.sms,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code incorrect. Réessaie.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: const Text('Vérification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text('Code de vérification', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text('Entrez le code envoyé au ${widget.phone}', style: const TextStyle(fontSize: 14, color: AppColors.grey500)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (i) => SizedBox(
                width: 46,
                height: 56,
                child: TextFormField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.grey100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) _focusNodes[i+1].requestFocus();
                    if (v.isEmpty && i > 0) _focusNodes[i-1].requestFocus();
                    if (_otp.length == 6) _verify();
                  },
                ),
              )),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Vérifier'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets communs ────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current, total;
  const _StepIndicator({required this.current, required this.total});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) => Expanded(
        child: Container(
          height: 4,
          margin: EdgeInsets.only(right: i < total-1 ? 6 : 0),
          decoration: BoxDecoration(
            color: i < current ? AppColors.primary : AppColors.grey200,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      )),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13))),
        ],
      ),
    );
  }
}

class _RoleOption {
  final String value, emoji, label, desc;
  const _RoleOption({required this.value, required this.emoji, required this.label, required this.desc});
}
