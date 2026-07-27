// lib/presentation/screens/home/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../main.dart';
import '../../../core/theme/app_colors.dart';

/// Écran des notifications (table `notifications` Supabase).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _loading = false;
        _items = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await supabase
          .from('notifications')
          .select('''
            id, type, title, body, data, is_read, created_at,
            sender:profiles!notifications_sender_id_fkey(full_name, avatar_url)
          ''')
          .eq('recipient_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      setState(() {
        _items = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Impossible de charger les notifications.';
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('recipient_id', uid)
          .eq('is_read', false);
      setState(() {
        for (final n in _items) {
          n['is_read'] = true;
        }
      });
    } catch (_) {}
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['is_read'] == true) return;
    setState(() => n['is_read'] = true);
    try {
      await supabase.from('notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', n['id'] as String);
    } catch (_) {}
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'profile_view':
        return Icons.visibility_outlined;
      case 'contact_request':
        return Icons.person_add_alt;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'expert_rating':
        return Icons.star_outline;
      case 'challenge':
        return Icons.emoji_events_outlined;
      case 'recruitment':
        return Icons.work_outline;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((n) => n['is_read'] != true);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alertes'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Tout lire'),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 140),
            Icon(Icons.notifications_none, size: 56, color: AppColors.grey400),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Aucune notification',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.grey200),
        itemBuilder: (context, i) {
          final n = _items[i];
          final isRead = n['is_read'] == true;
          final createdAt =
              DateTime.tryParse(n['created_at'] as String? ?? '');
          return ListTile(
            onTap: () => _markRead(n),
            tileColor: isRead ? null : AppColors.primaryBg,
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(
                _iconFor(n['type'] as String?),
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              n['title'] as String? ?? '',
              style: TextStyle(
                fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: (n['body'] as String?)?.isNotEmpty == true
                ? Text(
                    n['body'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
            trailing: Text(
              createdAt != null
                  ? timeago.format(createdAt, locale: 'fr')
                  : '',
              style:
                  const TextStyle(fontSize: 11, color: AppColors.grey400),
            ),
          );
        },
      ),
    );
  }
}
