// lib/data/repositories/messaging_repository.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConversationModel {
  final String id;
  final String participant1;
  final String participant2;
  final String? subject;
  final String? contactReason;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  // Données de l'autre participant
  final String? otherName;
  final String? otherAvatar;
  final String? otherRole;
  final String? otherSport;

  // Dernier message
  final String? lastMessageBody;
  final bool hasUnread;

  const ConversationModel({
    required this.id,
    required this.participant1,
    required this.participant2,
    this.subject,
    this.contactReason,
    this.lastMessageAt,
    required this.createdAt,
    this.otherName,
    this.otherAvatar,
    this.otherRole,
    this.otherSport,
    this.lastMessageBody,
    this.hasUnread = false,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> j, String myId) {
    final isP1   = j['participant_1'] as String == myId;
    final other  = isP1 ? j['participant_2_data'] : j['participant_1_data'];
    final otherM = other as Map<String, dynamic>?;

    return ConversationModel(
      id:             j['id'] as String,
      participant1:   j['participant_1'] as String,
      participant2:   j['participant_2'] as String,
      subject:        j['subject'] as String?,
      contactReason:  j['contact_reason'] as String?,
      lastMessageAt:  j['last_message_at'] != null
          ? DateTime.tryParse(j['last_message_at'] as String)
          : null,
      createdAt:      DateTime.parse(j['created_at'] as String),
      otherName:      otherM?['full_name'] as String?,
      otherAvatar:    otherM?['avatar_url'] as String?,
      otherRole:      otherM?['role'] as String?,
      lastMessageBody: j['last_message_body'] as String?,
      hasUnread:       j['has_unread'] as bool? ?? false,
    );
  }

  String get contactReasonLabel {
    switch (contactReason) {
      case 'recruitment_offer': return '📋 Offre de recrutement';
      case 'trial_invitation':  return '⚽ Invitation à un essai';
      case 'sponsorship':       return '💰 Sponsoring';
      default:                  return '💬 Contact général';
    }
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String? attachmentUrl;
  final String status;
  final DateTime createdAt;

  // Données expéditeur
  final String? senderName;
  final String? senderAvatar;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    this.attachmentUrl,
    required this.status,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
    id:             j['id'] as String,
    conversationId: j['conversation_id'] as String,
    senderId:       j['sender_id'] as String,
    body:           j['body'] as String,
    attachmentUrl:  j['attachment_url'] as String?,
    status:         j['status'] as String? ?? 'sent',
    createdAt:      DateTime.parse(j['created_at'] as String),
    senderName:     (j['sender'] as Map?)?['full_name'] as String?,
    senderAvatar:   (j['sender'] as Map?)?['avatar_url'] as String?,
  );

  bool isMe(String myId) => senderId == myId;
}

class MessagingRepository {
  final _client = Supabase.instance.client;
  String get _myId => _client.auth.currentUser!.id;

  // ── Conversations ──────────────────────────────────────
  Future<List<ConversationModel>> getConversations() async {
    final data = await _client.from('conversations').select('''
      *,
      participant_1_data:profiles!participant_1(full_name, avatar_url, role),
      participant_2_data:profiles!participant_2(full_name, avatar_url, role)
    ''')
    .or('participant_1.eq.$_myId,participant_2.eq.$_myId')
    .order('last_message_at', ascending: false, nullsFirst: false);

    return (data as List)
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>, _myId))
        .toList();
  }

  Future<ConversationModel?> getConversation(String conversationId) async {
    final data = await _client.from('conversations').select('''
      *,
      participant_1_data:profiles!participant_1(full_name, avatar_url, role),
      participant_2_data:profiles!participant_2(full_name, avatar_url, role)
    ''').eq('id', conversationId).maybeSingle();
    if (data == null) return null;
    return ConversationModel.fromJson(data, _myId);
  }

  // Vérifier si une conversation existe déjà
  Future<String?> findExistingConversation(String otherUserId) async {
    final data = await _client.from('conversations')
        .select('id')
        .or('and(participant_1.eq.$_myId,participant_2.eq.$otherUserId),and(participant_1.eq.$otherUserId,participant_2.eq.$_myId)')
        .maybeSingle();
    return data?['id'] as String?;
  }

  // Créer une conversation (demande de contact)
  Future<ConversationModel> createConversation({
    required String recipientId,
    required String subject,
    required String contactReason,
    required String firstMessage,
  }) async {
    // Vérifier si existe
    final existing = await findExistingConversation(recipientId);
    if (existing != null) {
      final conv = await getConversation(existing);
      if (conv != null) return conv;
    }

    // Créer la conversation
    final convData = await _client.from('conversations').insert({
      'participant_1':  _myId,
      'participant_2':  recipientId,
      'subject':        subject,
      'contact_reason': contactReason,
    }).select().single();

    final conv = ConversationModel.fromJson(convData, _myId);

    // Envoyer le premier message
    await sendMessage(conversationId: conv.id, body: firstMessage);

    return conv;
  }

  // ── Messages ───────────────────────────────────────────
  Future<List<MessageModel>> getMessages(String conversationId, {int limit = 50}) async {
    final data = await _client.from('messages').select('''
      *,
      sender:profiles!sender_id(full_name, avatar_url)
    ''')
    .eq('conversation_id', conversationId)
    .order('created_at', ascending: true)
    .limit(limit);

    return (data as List)
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String body,
    String? attachmentUrl,
  }) async {
    final data = await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id':       _myId,
      'body':            body,
      'attachment_url':  attachmentUrl,
      'status':          'sent',
    }).select('''
      *,
      sender:profiles!sender_id(full_name, avatar_url)
    ''').single();
    return MessageModel.fromJson(data);
  }

  // Marquer messages comme lus
  Future<void> markMessagesRead(String conversationId) async {
    await _client.from('messages')
        .update({'status': 'read'})
        .eq('conversation_id', conversationId)
        .neq('sender_id', _myId)
        .eq('status', 'sent');
  }

  // ── Realtime subscriptions ─────────────────────────────
  StreamSubscription<List<Map<String, dynamic>>> subscribeToMessages({
    required String conversationId,
    required void Function(MessageModel) onMessage,
  }) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .listen((data) {
          if (data.isNotEmpty) {
            final last = MessageModel.fromJson(data.last);
            if (last.senderId != _myId) onMessage(last);
          }
        });
  }

  StreamSubscription<List<Map<String, dynamic>>> subscribeToConversations({
    required void Function() onUpdate,
  }) {
    // Stream ne supporte pas .or() ni .order() — on écoute tous les changements
    // et on filtre côté appelant dans getConversations()
    return _client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .listen((_) => onUpdate());
  }

  // ── Vérification abonnement premium ───────────────────
  Future<bool> canAccessMessaging() async {
    final data = await _client
        .from('profiles')
        .select('subscription_plan, role')
        .eq('id', _myId)
        .single();
    final plan = data['subscription_plan'] as String;
    final role = data['role'] as String;
    // Recruteurs et admins ont toujours accès
    if (['recruiter', 'sponsor', 'admin', 'expert'].contains(role)) return true;
    // Sportifs uniquement si premium
    return plan == 'athlete_premium';
  }

  // ── Nombre non lus ─────────────────────────────────────
  Future<int> getUnreadCount() async {
    final data = await _client.from('messages')
        .select('id')
        .neq('sender_id', _myId)
        .eq('status', 'sent');
    return (data as List).length;
  }
}
