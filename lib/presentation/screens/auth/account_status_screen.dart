// lib/presentation/screens/auth/account_status_screen.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/common/logout_action.dart';

/// Écran affiché quand le compte n'est pas encore utilisable :
/// - status 'pending'  → en attente de validation par un admin
/// - status 'banned'   → compte refusé / bloqué
/// - status 'suspended'→ compte suspendu temporairement
class AccountStatusScreen extends StatelessWidget {
  final String status;

  /// Callback pour re-vérifier le statut (l'admin a peut-être validé).
  final Future<void> Function() onRefresh;

  const AccountStatusScreen({
    super.key,
    required this.status,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending';
    final isBanned = status == 'banned';

    final IconData icon;
    final Color color;
    final String title;
    final String message;

    if (isPending) {
      icon = Icons.hourglass_top_rounded;
      color = AppColors.accent;
      title = 'Compte en attente de validation';
      message =
          'Ton compte a bien été créé. Un administrateur doit le valider '
          'avant que tu puisses accéder à la plateforme.\n\n'
          'Tu recevras l\'accès dès qu\'il sera approuvé. Reviens vérifier '
          'dans quelques instants.';
    } else if (isBanned) {
      icon = Icons.block_rounded;
      color = AppColors.error;
      title = 'Compte non autorisé';
      message =
          'Ton compte n\'a pas été autorisé à accéder à la plateforme. '
          'Si tu penses qu\'il s\'agit d\'une erreur, contacte le support.';
    } else {
      // suspended
      icon = Icons.pause_circle_outline_rounded;
      color = AppColors.error;
      title = 'Compte suspendu';
      message =
          'Ton compte a été temporairement suspendu. Contacte le support '
          'pour plus d\'informations.';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [LogoutMenuButton()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: color),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.grey600,
                ),
              ),
              const SizedBox(height: 32),
              if (isPending)
                FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Vérifier mon statut'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
