import 'package:denota/core/router/app_router.dart';
// lib/presentation/screens/payment/payment_screen.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/payment_service.dart';

class PaymentScreen extends StatefulWidget {
  final PlanId? preselectedPlan;
  const PaymentScreen({super.key, this.preselectedPlan});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _paymentService = PaymentService();

  PlanModel? _selectedPlan;
  PaymentMethod? _selectedMethod;
  bool _processing = false;

  final _phoneCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.preselectedPlan != null) {
      _selectedPlan = kPlans.firstWhere((p) => p.id == widget.preselectedPlan);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedPlan == null || _selectedMethod == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _processing = true);
    try {
      final result = await _paymentService.processPayment(
        method:     _selectedMethod!,
        plan:       _selectedPlan!,
        userEmail:  '',
        userName:   '',
        userPhone:  _phoneCtrl.text.trim(),
      );

      if (!mounted) return;
      if (result.success) {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage ?? 'Erreur de paiement'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline, size: 52, color: AppColors.success),
            ),
            const SizedBox(height: 16),
            const Text('Paiement en cours de traitement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Votre abonnement sera activé dès confirmation du paiement. Vous recevrez une notification.', style: TextStyle(fontSize: 13, color: AppColors.grey500, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () { AppNavigator.goToFeed(); },
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Passer en Premium')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Titre ─────────────────────────────────
              const Text('Choisissez votre plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 4),
              const Text('Sans engagement · Résiliable à tout moment', style: TextStyle(fontSize: 13, color: AppColors.grey400)),
              const SizedBox(height: 20),

              // ── Plans ─────────────────────────────────
              ...kPlans.map((plan) => _PlanCard(
                plan:     plan,
                selected: _selectedPlan?.id == plan.id,
                onTap:    () => setState(() => _selectedPlan = plan),
              )),

              // ── Méthode de paiement ───────────────────
              if (_selectedPlan != null) ...[
                const SizedBox(height: 24),
                const Text('Méthode de paiement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 4),
                const Text('Paiement sécurisé 100% local', style: TextStyle(fontSize: 12, color: AppColors.grey400)),
                const SizedBox(height: 12),

                _PaymentMethodCard(
                  method:   PaymentMethod.cinetpay,
                  logo:     '🏦',
                  name:     'CinetPay',
                  subtitle: 'Wave, Orange Money, MTN, Moov, Carte bancaire',
                  selected: _selectedMethod == PaymentMethod.cinetpay,
                  onTap:    () => setState(() => _selectedMethod = PaymentMethod.cinetpay),
                ),
                const SizedBox(height: 8),
                _PaymentMethodCard(
                  method:   PaymentMethod.wave,
                  logo:     '🌊',
                  name:     'Wave CI',
                  subtitle: 'Paiement rapide via l\'app Wave',
                  selected: _selectedMethod == PaymentMethod.wave,
                  onTap:    () => setState(() => _selectedMethod = PaymentMethod.wave),
                ),
                const SizedBox(height: 8),
                _PaymentMethodCard(
                  method:   PaymentMethod.orangeMoney,
                  logo:     '🟠',
                  name:     'Orange Money',
                  subtitle: 'Code USSD Orange Money',
                  selected: _selectedMethod == PaymentMethod.orangeMoney,
                  onTap:    () => setState(() => _selectedMethod = PaymentMethod.orangeMoney),
                ),
              ],

              // ── Téléphone ─────────────────────────────
              if (_selectedMethod != null) ...[
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone Mobile Money',
                    prefixText: '+225 ',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '07 XX XX XX XX',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 8) return 'Numéro invalide';
                    return null;
                  },
                ),
              ],

              // ── Résumé & Bouton ───────────────────────
              if (_selectedPlan != null && _selectedMethod != null) ...[
                const SizedBox(height: 24),
                _PaymentSummary(plan: _selectedPlan!, method: _selectedMethod!),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _processing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  child: _processing
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text('Payer ${_selectedPlan!.priceXof.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA'),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 13, color: AppColors.grey400),
                      SizedBox(width: 4),
                      Text('Paiement sécurisé · Sans abonnement caché', style: TextStyle(fontSize: 11, color: AppColors.grey400)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Carte plan ────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final PlanModel plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPopular = plan.id == PlanId.athletePremium;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBg : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.grey200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (isPopular)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Center(
                  child: Text('⭐ Le plus populaire', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plan.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: selected ? AppColors.primary : AppColors.ink)),
                            Text(plan.description, style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${plan.priceXof.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: selected ? AppColors.primary : AppColors.ink),
                          ),
                          Text(plan.durationLabel, style: const TextStyle(fontSize: 11, color: AppColors.grey400)),
                        ],
                      ),
                    ],
                  ),

                  if (selected) ...[
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.grey200, height: 1),
                    const SizedBox(height: 10),
                    ...plan.features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(f, style: const TextStyle(fontSize: 12, color: AppColors.grey600, height: 1.4)),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Méthode de paiement ───────────────────────────────────
class _PaymentMethodCard extends StatelessWidget {
  final PaymentMethod method;
  final String logo, name, subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.method, required this.logo, required this.name,
    required this.subtitle, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBg : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : AppColors.grey200, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Text(logo, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.ink)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.grey400)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Résumé ────────────────────────────────────────────────
class _PaymentSummary extends StatelessWidget {
  final PlanModel plan;
  final PaymentMethod method;
  const _PaymentSummary({required this.plan, required this.method});

  String get _methodLabel {
    switch (method) {
      case PaymentMethod.cinetpay:    return 'CinetPay';
      case PaymentMethod.wave:        return 'Wave CI';
      case PaymentMethod.orangeMoney: return 'Orange Money';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _row('Plan', plan.name),
          const SizedBox(height: 6),
          _row('Durée', '1 mois renouvelable'),
          const SizedBox(height: 6),
          _row('Méthode', _methodLabel),
          const Divider(color: AppColors.primary, height: 20),
          Row(
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
              const Spacer(),
              Text(
                '${plan.priceXof.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.grey500)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
    ],
  );
}
