// lib/data/services/payment_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

// ── Modèles ───────────────────────────────────────────────
enum PaymentMethod { cinetpay, wave, orangeMoney }

enum PlanId {
  athletePremium,
  institutionStarter,
  institutionPro,
  recruiterPro,
}

class PlanModel {
  final PlanId id;
  final String name;
  final String description;
  final int priceXof;        // Prix en FCFA
  final String durationLabel;
  final List<String> features;
  final String supabasePlan; // valeur dans la DB

  const PlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceXof,
    required this.durationLabel,
    required this.features,
    required this.supabasePlan,
  });
}

const kPlans = [
  PlanModel(
    id:            PlanId.athletePremium,
    name:          'Sportif Premium',
    description:   'Pour les athlètes qui veulent être recrutés',
    priceXof:      3000,
    durationLabel: 'par mois',
    supabasePlan:  'athlete_premium',
    features: [
      '✅ Messagerie avec recruteurs',
      '✅ Analytics de votre profil',
      '✅ Profil boosté dans les recherches',
      '✅ Badge Premium visible',
      '✅ Stories et publications prioritaires',
    ],
  ),
  PlanModel(
    id:            PlanId.institutionStarter,
    name:          'Institution Starter',
    description:   'Clubs et écoles jusqu\'à 20 sportifs',
    priceXof:      15000,
    durationLabel: 'par mois',
    supabasePlan:  'institution_starter',
    features: [
      '✅ Jusqu\'à 20 profils d\'athlètes',
      '✅ Page officielle de l\'institution',
      '✅ Tableau de bord multi-athlètes',
      '✅ Analytics agrégées',
      '✅ Badge Institution Vérifiée',
    ],
  ),
  PlanModel(
    id:            PlanId.institutionPro,
    name:          'Institution Pro',
    description:   'Académies jusqu\'à 100 sportifs',
    priceXof:      40000,
    durationLabel: 'par mois',
    supabasePlan:  'institution_pro',
    features: [
      '✅ Jusqu\'à 100 profils d\'athlètes',
      '✅ Tout Institution Starter',
      '✅ Live streaming',
      '✅ Export données PDF',
      '✅ Support prioritaire',
    ],
  ),
  PlanModel(
    id:            PlanId.recruiterPro,
    name:          'Recruteur Pro',
    description:   'Agents, clubs professionnels, sponsors',
    priceXof:      25000,
    durationLabel: 'par mois',
    supabasePlan:  'recruiter_pro',
    features: [
      '✅ Recherche illimitée de talents',
      '✅ Filtres avancés + alertes',
      '✅ Accès profils mineurs vérifiés',
      '✅ Rapports PDF de scouting illimités',
      '✅ Messagerie directe',
    ],
  ),
];

class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? errorMessage;

  const PaymentResult({required this.success, this.transactionId, this.errorMessage});
}

// ── Service Paiement ──────────────────────────────────────
class PaymentService {
  final _client   = Supabase.instance.client;
  final _dio      = Dio();
  final _uuid     = const Uuid();

  // ── CinetPay ──────────────────────────────────────────
  // Documentation : https://docs.cinetpay.com
  static const String _cinetpayApiKey  = 'VOTRE_API_KEY_CINETPAY';
  static const String _cinetpaySiteId  = 'VOTRE_SITE_ID_CINETPAY';
  static const String _cinetpayBaseUrl = 'https://api-checkout.cinetpay.com/v2';

  Future<String?> _initCinetPayPayment({
    required int amountXof,
    required String description,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String returnUrl,
    required String notifyUrl,
  }) async {
    final transId = 'DENOTA_${_uuid.v4().replaceAll('-', '').substring(0, 16).toUpperCase()}';
    try {
      final res = await _dio.post(
        '$_cinetpayBaseUrl/payment',
        data: {
          'apikey':          _cinetpayApiKey,
          'site_id':         _cinetpaySiteId,
          'transaction_id':  transId,
          'amount':          amountXof,
          'currency':        'XOF',
          'description':     description,
          'return_url':      returnUrl,
          'notify_url':      notifyUrl,
          'customer_name':   customerName,
          'customer_email':  customerEmail,
          'customer_phone_number': customerPhone,
          'customer_country':      'CI',
          'channels':        'ALL', // Tous canaux : Wave, OM, MTN, CB...
          'lang':            'fr',
        },
      );
      if (res.data['code'] == '201') {
        return res.data['data']['payment_url'] as String?;
      }
      return null;
    } catch (_) { return null; }
  }

  // ── Wave CI ───────────────────────────────────────────
  // Deep link Wave CI : wave://pay?amount=X&name=Y&merchant_id=Z
  Future<bool> _payWithWave({
    required int amountXof,
    required String merchantId,
    required String description,
  }) async {
    final uri = Uri.parse(
      'https://pay.wave.com/m/$merchantId/c/ci?amount=$amountXof&currency=XOF&description=${Uri.encodeComponent(description)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  // ── Orange Money CI ───────────────────────────────────
  Future<bool> _payWithOrangeMoney({
    required int amountXof,
    required String merchantCode,
    required String orderId,
  }) async {
    // Orange Money CI via USSD ou lien marchand
    final uri = Uri.parse('tel:#144*82*${merchantCode}*${amountXof}*${orderId}#');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  // ── Méthode principale ────────────────────────────────
  Future<PaymentResult> processPayment({
    required PaymentMethod method,
    required PlanModel plan,
    required String userEmail,
    required String userName,
    required String userPhone,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const PaymentResult(success: false, errorMessage: 'Non connecté');

    // Enregistrer la tentative en DB
    final paymentRecord = await _client.from('payment_attempts').insert({
      'user_id':     userId,
      'plan':        plan.supabasePlan,
      'amount_xof':  plan.priceXof,
      'method':      method.name,
      'status':      'pending',
    }).select().single();

    final paymentId = paymentRecord['id'] as String;

    switch (method) {
      case PaymentMethod.cinetpay:
        final url = await _initCinetPayPayment(
          amountXof:     plan.priceXof,
          description:   'DeNoTa — ${plan.name}',
          customerName:  userName,
          customerEmail: userEmail,
          customerPhone: userPhone,
          returnUrl:     'https://denota.ci/payment/return?id=$paymentId',
          notifyUrl:     'https://YOUR_SUPABASE_URL/functions/v1/payment-webhook',
        );
        if (url != null) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          return PaymentResult(success: true, transactionId: paymentId);
        }
        return const PaymentResult(success: false, errorMessage: 'Impossible d\'ouvrir CinetPay');

      case PaymentMethod.wave:
        final ok = await _payWithWave(
          amountXof:  plan.priceXof,
          merchantId: 'VOTRE_MERCHANT_ID_WAVE',
          description: 'DeNoTa ${plan.name}',
        );
        if (ok) return PaymentResult(success: true, transactionId: paymentId);
        return const PaymentResult(success: false, errorMessage: 'Wave CI non disponible');

      case PaymentMethod.orangeMoney:
        final ok = await _payWithOrangeMoney(
          amountXof:    plan.priceXof,
          merchantCode: 'VOTRE_CODE_MARCHANDE_OM',
          orderId:      paymentId,
        );
        if (ok) return PaymentResult(success: true, transactionId: paymentId);
        return const PaymentResult(success: false, errorMessage: 'Orange Money non disponible');
    }
  }

  // ── Activation abonnement (appelée après webhook) ─────
  Future<void> activateSubscription({
    required String userId,
    required String plan,
    int durationDays = 30,
  }) async {
    final expiresAt = DateTime.now().add(Duration(days: durationDays));
    await _client.from('profiles').update({
      'subscription_plan':       plan,
      'subscription_expires_at': expiresAt.toIso8601String(),
    }).eq('id', userId);
  }

  // ── Vérifier abonnement actif ─────────────────────────
  Future<bool> hasActiveSubscription() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final data = await _client.from('profiles').select('subscription_plan, subscription_expires_at').eq('id', userId).single();
    final plan    = data['subscription_plan'] as String;
    final expires = data['subscription_expires_at'] as String?;
    if (plan == 'free') return false;
    if (expires == null) return true;
    return DateTime.parse(expires).isAfter(DateTime.now());
  }
}

// ── Migration SQL payment_attempts ───────────────────────
// À ajouter dans Supabase SQL Editor :
/*
CREATE TABLE payment_attempts (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID REFERENCES profiles(id) ON DELETE CASCADE,
  plan        TEXT NOT NULL,
  amount_xof  INTEGER NOT NULL,
  method      TEXT NOT NULL,
  status      TEXT DEFAULT 'pending', -- pending | success | failed
  transaction_id TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE payment_attempts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "payment_own" ON payment_attempts FOR ALL USING (auth.uid() = user_id);
*/
