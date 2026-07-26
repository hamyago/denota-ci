// lib/data/services/scouting_pdf_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../data/repositories/profile_repository.dart';

// Couleurs DeNoTa pour le PDF
const _green   = PdfColor.fromInt(0xFF1B5E3B);
const _gold    = PdfColor.fromInt(0xFFF5A623);
const _ink     = PdfColor.fromInt(0xFF0D1B2A);
const _grey    = PdfColor.fromInt(0xFF6B7785);
const _bgGreen = PdfColor.fromInt(0xFFE8F5EE);
const _bgGold  = PdfColor.fromInt(0xFFFDF3DC);
const _white   = PdfColors.white;

class ScoutingPdfService {
  final _profileRepo = ProfileRepository();

  Future<File> generateScoutingReport({
    required String athleteId,
    required String recruiterName,
    required String recruiterOrg,
  }) async {
    // Charger les données
    final profile        = await _profileRepo.getProfile(athleteId);
    final athleteProfile = await _profileRepo.getAthleteProfile(athleteId);
    final stats          = await _profileRepo.getAthleteStats(athleteId);
    final ratings        = await _profileRepo.getExpertRatings(athleteId);
    final achievements   = await _profileRepo.getAchievements(athleteId);
    final posts          = await _profileRepo.getProfilePosts(athleteId);
    final followers      = await _profileRepo.getFollowersCount(athleteId);

    if (profile == null) throw Exception('Profil introuvable');

    final pdf = pw.Document();

    // ── Calculs ─────────────────────────────────────────
    final avgScore = ratings.isEmpty
        ? 0.0
        : ratings.map((r) => r.globalScore).reduce((a, b) => a + b) / ratings.length;

    final avgTech = ratings.isEmpty ? 0.0 : ratings.map((r) => r.techniqueScore).reduce((a, b) => a + b) / ratings.length;
    final avgPhys = ratings.isEmpty ? 0.0 : ratings.map((r) => r.physicalScore).reduce((a, b) => a + b) / ratings.length;
    final avgMent = ratings.isEmpty ? 0.0 : ratings.map((r) => r.mentalScore).reduce((a, b) => a + b) / ratings.length;
    final avgStat = ratings.isEmpty ? 0.0 : ratings.map((r) => r.statsScore).reduce((a, b) => a + b) / ratings.length;
    final avgPot  = ratings.isEmpty ? 0.0 : ratings.map((r) => r.potentialScore).reduce((a, b) => a + b) / ratings.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [

          // ── HEADER ──────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: _green,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(children: [
                        pw.TextSpan('De', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: _white)),
                        pw.TextSpan('No', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: _gold)),
                        pw.TextSpan('Ta', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: _white)),
                      ]),
                    ),
                    pw.Text('Rapport de Scouting', style: pw.TextStyle(fontSize: 12, color: PdfColor.fromInt(0xFF9FE1CB))),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('CONFIDENTIEL', style: pw.TextStyle(fontSize: 9, color: _gold, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
                    pw.SizedBox(height: 4),
                    pw.Text('Généré le ${_formatDate(DateTime.now())}', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF9FE1CB))),
                    pw.Text('Par $recruiterName · $recruiterOrg', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF9FE1CB))),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // ── IDENTITÉ SPORTIF ─────────────────────────
          _sectionTitle('Identité du Sportif'),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _bgGreen,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: _green, width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Infos principales
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(profile.fullName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink)),
                      pw.Text('@${profile.username}', style: pw.TextStyle(fontSize: 11, color: _grey)),
                      pw.SizedBox(height: 10),
                      _infoRow('Sport', athleteProfile?.primarySportName ?? '—'),
                      _infoRow('Poste', athleteProfile?.primaryPositionName ?? '—'),
                      _infoRow('Niveau', athleteProfile?.levelLabel ?? '—'),
                      _infoRow('Club', athleteProfile?.currentClub ?? '—'),
                      _infoRow('Ville', profile.city ?? '—'),
                      _infoRow('Âge', profile.age > 0 ? '${profile.age} ans' : '—'),
                      _infoRow('Nationalité', profile.country),
                      if (profile.isMinor)
                        pw.Container(
                          margin: const pw.EdgeInsets.only(top: 6),
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: pw.BoxDecoration(color: _bgGold, borderRadius: pw.BorderRadius.circular(4)),
                          child: pw.Text('⚠ Mineur — Autorisation parentale requise',
                              style: pw.TextStyle(fontSize: 9, color: _gold, fontWeight: pw.FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                // Métriques rapides
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      _metricBox('Talent Score™', '${athleteProfile?.talentScore.toStringAsFixed(0) ?? "–"}/100', _gold),
                      pw.SizedBox(height: 8),
                      _metricBox('Taille', athleteProfile?.heightCm != null ? '${athleteProfile!.heightCm!.round()} cm' : '—', _green),
                      pw.SizedBox(height: 8),
                      _metricBox('Poids', athleteProfile?.weightKg != null ? '${athleteProfile!.weightKg!.round()} kg' : '—', _green),
                      pw.SizedBox(height: 8),
                      _metricBox('Abonnés', '$followers', PdfColor.fromInt(0xFF1A73C8)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ── DISPONIBILITÉ ────────────────────────────
          if (athleteProfile?.availability != null) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFEAF3DE),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromInt(0xFF3B6D11), width: 0.5),
              ),
              child: pw.Row(
                children: [
                  pw.Text('📅 Disponibilité : ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _green)),
                  pw.Text(athleteProfile!.availabilityLabel, style: pw.TextStyle(fontSize: 11, color: _ink)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── ÉVALUATIONS EXPERTS ──────────────────────
          if (ratings.isNotEmpty) ...[
            _sectionTitle('Évaluations des Experts'),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromInt(0xFFD0D7DE), width: 0.5),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  // Score global
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text('Score global : ', style: pw.TextStyle(fontSize: 13, color: _grey)),
                      pw.Text('${avgScore.toStringAsFixed(1)}/10', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _gold)),
                      pw.Text(' (${ratings.length} expert${ratings.length > 1 ? "s" : ""})', style: pw.TextStyle(fontSize: 11, color: _grey)),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(color: PdfColor.fromInt(0xFFE8ECF0)),
                  pw.SizedBox(height: 12),
                  // Critères
                  _criteriaRow('Technique',      avgTech, 0.30),
                  pw.SizedBox(height: 6),
                  _criteriaRow('Physique',        avgPhys, 0.25),
                  pw.SizedBox(height: 6),
                  _criteriaRow('Mental / Attitude', avgMent, 0.20),
                  pw.SizedBox(height: 6),
                  _criteriaRow('Statistiques',    avgStat, 0.15),
                  pw.SizedBox(height: 6),
                  _criteriaRow('Potentiel',        avgPot,  0.10),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── STATISTIQUES SPORTIVES ───────────────────
          if (stats.isNotEmpty) ...[
            _sectionTitle('Statistiques Sportives'),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE8ECF0), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _green),
                  children: ['Saison', 'Matchs', 'V', 'D', 'N'].map((h) =>
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: pw.Text(h, style: pw.TextStyle(fontSize: 10, color: _white, fontWeight: pw.FontWeight.bold)),
                    ),
                  ).toList(),
                ),
                ...stats.take(5).map((s) => pw.TableRow(
                  children: [
                    s.season ?? 'Actuelle',
                    '${s.matchesPlayed}', '${s.wins}', '${s.losses}', '${s.draws}',
                  ].map((v) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: pw.Text(v, style: pw.TextStyle(fontSize: 10, color: _ink)),
                  )).toList(),
                )),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── PALMARÈS ─────────────────────────────────
          if (achievements.isNotEmpty) ...[
            _sectionTitle('Palmarès'),
            pw.SizedBox(height: 8),
            pw.Column(
              children: achievements.take(6).map((a) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: _bgGold,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('🏆 ', style: const pw.TextStyle(fontSize: 12)),
                    pw.Expanded(
                      child: pw.Text(a.title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
                    ),
                    if (a.year != null)
                      pw.Text('${a.year}', style: pw.TextStyle(fontSize: 10, color: _grey)),
                  ],
                ),
              )).toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── ACTIVITÉ PLATEFORME ───────────────────────
          _sectionTitle('Activité sur DeNoTa'),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _activityCard('Publications', '${posts.length}'),
              pw.SizedBox(width: 10),
              _activityCard('Abonnés', '$followers'),
              pw.SizedBox(width: 10),
              _activityCard('Vues profil', '${profile.profileViews}'),
              pw.SizedBox(width: 10),
              _activityCard('Score profil', '${profile.profileScore}%'),
            ],
          ),

          pw.SizedBox(height: 24),

          // ── FOOTER ───────────────────────────────────
          pw.Divider(color: _green),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('denota.ci · Détection de Nouveaux Talents', style: pw.TextStyle(fontSize: 8, color: _grey)),
              pw.Text('Rapport confidentiel · Usage exclusif recruteur', style: pw.TextStyle(fontSize: 8, color: _grey)),
              pw.Text('Page 1', style: pw.TextStyle(fontSize: 8, color: _grey)),
            ],
          ),
        ],
      ),
    );

    // ── Sauvegarder ───────────────────────────────────────
    final dir = await getApplicationDocumentsDirectory();
    final slug = profile.username.replaceAll(' ', '_');
    final file = File('${dir.path}/scouting_${slug}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── Partager le PDF ────────────────────────────────────
  Future<void> shareReport(File file, String athleteName) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Rapport de scouting — $athleteName — DeNoTa',
      text: 'Rapport de scouting généré par DeNoTa CI',
    );
  }

  // ── Helpers visuels PDF ───────────────────────────────
  pw.Widget _sectionTitle(String title) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    decoration: pw.BoxDecoration(
      border: pw.Border(left: pw.BorderSide(color: _gold, width: 4)),
    ),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _ink)),
  );

  pw.Widget _infoRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 80, child: pw.Text(label, style: pw.TextStyle(fontSize: 10, color: _grey))),
        pw.Text(': ', style: pw.TextStyle(fontSize: 10, color: _grey)),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink))),
      ],
    ),
  );

  pw.Widget _metricBox(String label, String value, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(color: _white, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: color, width: 1)),
    child: pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
      pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _grey)),
    ]),
  );

  pw.Widget _criteriaRow(String label, double score, double weight) {
    final barWidth = (score / 10).clamp(0.0, 1.0);
    return pw.Row(children: [
      pw.SizedBox(width: 110, child: pw.Text(label, style: pw.TextStyle(fontSize: 10, color: _ink))),
      pw.SizedBox(width: 8),
      pw.Expanded(
        child: pw.Stack(children: [
          pw.Container(height: 8, decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8ECF0), borderRadius: pw.BorderRadius.circular(4))),
          pw.FractionallySizedBox(
            widthFactor: barWidth,
            child: pw.Container(height: 8, decoration: pw.BoxDecoration(color: _green, borderRadius: pw.BorderRadius.circular(4))),
          ),
        ]),
      ),
      pw.SizedBox(width: 8),
      pw.SizedBox(width: 30, child: pw.Text('${score.toStringAsFixed(1)}/10', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _green))),
      pw.SizedBox(width: 4),
      pw.Text('(${(weight * 100).round()}%)', style: pw.TextStyle(fontSize: 8, color: _grey)),
    ]);
  }

  pw.Widget _activityCard(String label, String value) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _bgGreen,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _green, width: 0.5),
      ),
      child: pw.Column(children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _green)),
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _grey)),
      ]),
    ),
  );

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}
