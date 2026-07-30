// lib/presentation/widgets/common/logout_action.dart
import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';

/// Affiche une boîte de dialogue de confirmation puis déconnecte
/// l'utilisateur et le renvoie vers l'écran de connexion.
/// Réutilisable depuis n'importe quelle AppBar (recruteur, admin, etc.).
Future<void> showLogoutDialog(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Déconnexion'),
      content: const Text('Es-tu sûr de vouloir te déconnecter ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: const Text('Déconnecter', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirm == true) {
    await supabase.auth.signOut();
    AppNavigator.goToLogin();
  }
}

/// Bouton d'engrenage prêt à l'emploi pour les AppBar : ouvre un menu
/// avec l'option de déconnexion.
class LogoutMenuButton extends StatelessWidget {
  const LogoutMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Paramètres',
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (sheetCtx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Se déconnecter',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    showLogoutDialog(context);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
