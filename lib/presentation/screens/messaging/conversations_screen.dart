// lib/presentation/screens/messaging/conversations_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/messaging_repository.dart';
import '../../../main.dart';

// ══════════════════════════════════════════════════════════════
// CONVERSATIONS LIST
// ══════════════════════════════════════════════════════════════
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _repo = MessagingRepository();
  List<ConversationModel> _conversations = [];
  bool _loading = true;
  bool _canAccess = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final canAccess = await _repo.canAccessMessaging();
    if (!mounted) return;
    setState(() => _canAccess = canAccess);
    if (canAccess) {
      await _load();
      _sub = _repo.subscribeToConversations(onUpdate: _load);
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    final convs = await _repo.getConversations();
    if (!mounted) return;
    setState(() { _conversations = convs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          if (_canAccess)
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : !_canAccess
              ? _PremiumGate()
              : _conversations.isEmpty
                  ? _EmptyMessages()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        itemCount: _conversations.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 76, color: AppColors.grey200),
                        itemBuilder: (_, i) => _ConversationTile(
                          conv: _conversations[i],
                          onTap: () => context.push('/chat/${_conversations[i].id}'),
                        ),
                      ),
                    ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationModel conv;
  final VoidCallback onTap;
  const _ConversationTile({required this.conv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
      tileColor: conv.hasUnread ? AppColors.primaryBg.withValues(alpha: 0.4) : null,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primaryBg,
            backgroundImage: conv.otherAvatar != null
                ? CachedNetworkImageProvider(conv.otherAvatar!)
                : null,
            child: conv.otherAvatar == null
                ? Text(
                    (conv.otherName ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18),
                  )
                : null,
          ),
          if (conv.hasUnread)
            Positioned(
              top: 0, right: 0,
              child: Container(
                width: 12, height: 12,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conv.otherName ?? 'Inconnu',
              style: TextStyle(
                fontWeight: conv.hasUnread ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15, color: AppColors.ink,
              ),
            ),
          ),
          Text(
            conv.lastMessageAt != null ? timeago.format(conv.lastMessageAt!, locale: 'fr') : '',
            style: TextStyle(
              fontSize: 11,
              color: conv.hasUnread ? AppColors.primary : AppColors.grey300,
              fontWeight: conv.hasUnread ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conv.subject != null)
            Text(conv.contactReasonLabel,
                style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500)),
          Text(
            conv.lastMessageBody ?? conv.subject ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: conv.hasUnread ? AppColors.grey700 : AppColors.grey400,
              fontWeight: conv.hasUnread ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppColors.accentLight, shape: BoxShape.circle),
              child: const Icon(Icons.lock_outlined, size: 48, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            const Text('Messagerie Premium', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 12),
            const Text(
              'La messagerie est réservée aux sportifs Premium et aux recruteurs vérifiés.\n\nPassez en Premium pour recevoir et envoyer des messages directement aux recruteurs.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.grey500, height: 1.6),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.star_outlined),
              label: const Text('Passer en Premium'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            ),
            const SizedBox(height: 12),
            const Text('À partir de 2 000 FCFA / mois', style: TextStyle(fontSize: 12, color: AppColors.grey400)),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.grey300),
          SizedBox(height: 16),
          Text('Aucun message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey500)),
          SizedBox(height: 8),
          Text('Vos conversations avec les recruteurs\napparaîtront ici.', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.grey400)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CHAT SCREEN
// ══════════════════════════════════════════════════════════════
class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repo       = MessagingRepository();
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _myId       = supabase.auth.currentUser?.id ?? '';

  ConversationModel? _conv;
  List<MessageModel> _messages = [];
  bool _loading   = true;
  bool _sending   = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _repo.getConversation(widget.conversationId),
      _repo.getMessages(widget.conversationId),
    ]);
    if (!mounted) return;
    setState(() {
      _conv     = results[0] as ConversationModel?;
      _messages = results[1] as List<MessageModel>;
      _loading  = false;
    });
    _scrollToBottom();
    _repo.markMessagesRead(widget.conversationId);

    // Écouter les nouveaux messages en temps réel
    _sub = _repo.subscribeToMessages(
      conversationId: widget.conversationId,
      onMessage: (msg) {
        if (mounted) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
          _repo.markMessagesRead(widget.conversationId);
        }
      },
    );
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (animated) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    _msgCtrl.clear();
    setState(() => _sending = true);

    // Optimistic update
    final optimistic = MessageModel(
      id:             'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId:       _myId,
      body:           text,
      status:         'sent',
      createdAt:      DateTime.now(),
    );
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      final sent = await _repo.sendMessage(conversationId: widget.conversationId, body: text);
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == optimistic.id);
          _messages.add(sent);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == optimistic.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'envoi : $e'), backgroundColor: AppColors.error),
        );
        _msgCtrl.text = text;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _conv == null
            ? const Text('Conversation')
            : GestureDetector(
                onTap: () => context.push('/profile/${_conv!.participant1 == _myId ? _conv!.participant2 : _conv!.participant1}'),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryBg,
                      backgroundImage: _conv!.otherAvatar != null
                          ? CachedNetworkImageProvider(_conv!.otherAvatar!)
                          : null,
                      child: _conv!.otherAvatar == null
                          ? Text((_conv!.otherName ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_conv!.otherName ?? 'Inconnu',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                        if (_conv!.subject != null)
                          Text(_conv!.contactReasonLabel,
                              style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // ── Contexte du contact ──────────────────
                if (_conv?.subject != null)
                  _ContactContextBanner(conv: _conv!),

                // ── Messages ─────────────────────────────
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(child: Text('Démarrez la conversation', style: TextStyle(color: AppColors.grey400)))
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final msg  = _messages[i];
                            final isMe = msg.isMe(_myId);
                            final showDate = i == 0 ||
                                !_isSameDay(_messages[i - 1].createdAt, msg.createdAt);
                            final showAvatar = !isMe &&
                                (i == _messages.length - 1 || _messages[i + 1].senderId != msg.senderId);

                            return Column(
                              children: [
                                if (showDate) _DateDivider(date: msg.createdAt),
                                _MessageBubble(
                                  message:    msg,
                                  isMe:       isMe,
                                  showAvatar: showAvatar,
                                  avatar:     _conv?.otherAvatar,
                                  name:       _conv?.otherName,
                                ),
                              ],
                            );
                          },
                        ),
                ),

                // ── Barre de saisie ───────────────────────
                _InputBar(
                  controller: _msgCtrl,
                  sending: _sending,
                  onSend: _send,
                  onAttachment: () {},
                ),
              ],
            ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Bannière contexte ─────────────────────────────────────
class _ContactContextBanner extends StatelessWidget {
  final ConversationModel conv;
  const _ContactContextBanner({required this.conv});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primaryBg,
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${conv.contactReasonLabel}${conv.subject != null ? " · ${conv.subject}" : ""}",
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bulle de message ──────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;
  final String? avatar;
  final String? name;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    this.avatar,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (destinataire)
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: showAvatar
                  ? CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primaryBg,
                      backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar!) : null,
                      child: avatar == null
                          ? Text((name ?? '?')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 10, color: AppColors.primary))
                          : null,
                    )
                  : const SizedBox(width: 28),
            ),

          // Bulle
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    border: isMe ? null : Border.all(color: AppColors.grey200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    message.body,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : AppColors.ink,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.grey300),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.status == 'read' ? Icons.done_all : Icons.done,
                        size: 12,
                        color: message.status == 'read' ? AppColors.primary : AppColors.grey300,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Séparateur de date ────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String _label() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    if (d == today) return "Aujourd'hui";
    if (d == today.subtract(const Duration(days: 1))) return 'Hier';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.grey200)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_label(), style: const TextStyle(fontSize: 11, color: AppColors.grey400, fontWeight: FontWeight.w500)),
          ),
          const Expanded(child: Divider(color: AppColors.grey200)),
        ],
      ),
    );
  }
}

// ── Barre de saisie ───────────────────────────────────────
class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttachment;

  const _InputBar({required this.controller, required this.sending, required this.onSend, required this.onAttachment});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final has = widget.controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: const Border(top: BorderSide(color: AppColors.grey200)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_outlined, color: AppColors.grey400),
              onPressed: widget.onAttachment,
            ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Votre message...',
                  filled: true,
                  fillColor: AppColors.grey100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: widget.onSend,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _hasText ? AppColors.primary : AppColors.grey200,
                    shape: BoxShape.circle,
                  ),
                  child: widget.sending
                      ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CONTACT REQUEST DIALOG
// ══════════════════════════════════════════════════════════════
class ContactRequestDialog extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const ContactRequestDialog({super.key, required this.athleteId, required this.athleteName});

  static Future<void> show(BuildContext context, {required String athleteId, required String athleteName}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContactRequestDialog(athleteId: athleteId, athleteName: athleteName),
    );
  }

  @override
  State<ContactRequestDialog> createState() => _ContactRequestDialogState();
}

class _ContactRequestDialogState extends State<ContactRequestDialog> {
  final _repo      = MessagingRepository();
  final _msgCtrl   = TextEditingController();
  final _subCtrl   = TextEditingController();
  String _reason   = 'recruitment_offer';
  bool _sending    = false;

  final _reasons = const {
    'recruitment_offer': '📋 Offre de recrutement',
    'trial_invitation':  '⚽ Invitation à un essai',
    'sponsorship':       '💰 Proposition de sponsoring',
    'other':             '💬 Autre',
  };

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final conv = await _repo.createConversation(
        recipientId:  widget.athleteId,
        subject:      _subCtrl.text.trim().isEmpty ? _reasons[_reason]! : _subCtrl.text.trim(),
        contactReason: _reason,
        firstMessage: _msgCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      context.push('/chat/${conv.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('Contacter ${widget.athleteName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text('Présentez votre démarche clairement pour maximiser vos chances de réponse.',
                style: TextStyle(fontSize: 13, color: AppColors.grey500)),
            const SizedBox(height: 20),

            // Motif
            const Text('Motif du contact', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.grey600)),
            const SizedBox(height: 8),
            ..._reasons.entries.map((e) => RadioListTile<String>(
              value:    e.key,
              groupValue: _reason,
              title:    Text(e.value, style: const TextStyle(fontSize: 14)),
              dense:    true,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _reason = v!),
            )),

            const SizedBox(height: 12),
            TextFormField(
              controller: _subCtrl,
              decoration: const InputDecoration(
                labelText: 'Objet (optionnel)',
                hintText: 'Ex: Intégration équipe U21 ASEC Mimosas',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _msgCtrl,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Message *',
                hintText: 'Présentez-vous, votre structure, et ce que vous proposez...',
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: const Text('Envoyer la demande de contact'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
