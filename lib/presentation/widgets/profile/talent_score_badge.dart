// lib/presentation/widgets/profile/talent_score_badge.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/theme/app_colors.dart';

class TalentScoreBadge extends StatefulWidget {
  final double score;
  final double size;
  final bool showLabel;

  const TalentScoreBadge({
    super.key,
    required this.score,
    this.size = 100,
    this.showLabel = true,
  });

  @override
  State<TalentScoreBadge> createState() => _TalentScoreBadgeState();
}

class _TalentScoreBadgeState extends State<TalentScoreBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _anim = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _scoreColor {
    final s = widget.score;
    if (s >= 80) return AppColors.accent;
    if (s >= 60) return AppColors.success;
    if (s >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ScorePainter(
              progress: _anim.value,
              score: (widget.score * _anim.value).round(),
              color: _scoreColor,
            ),
          ),
        ),
        if (widget.showLabel) ...[
          const SizedBox(height: 6),
          const Text(
            'Talent Score™',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.grey500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }
}

class _ScorePainter extends CustomPainter {
  final double progress;
  final int score;
  final Color color;

  _ScorePainter({
    required this.progress,
    required this.score,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 10;

    // Track (arrière-plan)
    final trackPaint = Paint()
      ..color = AppColors.grey200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      trackPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      progressPaint,
    );

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi * 0.75,
        math.pi * 1.5 * progress,
        false,
        glowPaint,
      );
    }

    // Score text
    final scorePainter = TextPainter(
      text: TextSpan(
        text: score.toString(),
        style: TextStyle(
          fontSize: size.width * 0.28,
          fontWeight: FontWeight.w700,
          color: color,
          fontFamily: 'Poppins',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    scorePainter.paint(
      canvas,
      Offset(cx - scorePainter.width / 2, cy - scorePainter.height / 2 - 6),
    );

    // /100 sous le score
    final subPainter = TextPainter(
      text: const TextSpan(
        text: '/100',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: AppColors.grey400,
          fontFamily: 'Poppins',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    subPainter.paint(
      canvas,
      Offset(cx - subPainter.width / 2, cy + scorePainter.height / 2 - 8),
    );
  }

  @override
  bool shouldRepaint(covariant _ScorePainter old) =>
      old.progress != progress || old.score != score;
}

// ── Score bar compact ─────────────────────────────────────
class TalentScoreBar extends StatefulWidget {
  final double score;
  final String label;
  final Color? color;

  const TalentScoreBar({
    super.key,
    required this.score,
    required this.label,
    this.color,
  });

  @override
  State<TalentScoreBar> createState() => _TalentScoreBarState();
}

class _TalentScoreBarState extends State<TalentScoreBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _anim = Tween<double>(begin: 0, end: widget.score / 10)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), _ctrl.forward);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.grey700)),
            Text(widget.score.toStringAsFixed(1),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _anim.value / 10,
              minHeight: 6,
              backgroundColor: AppColors.grey200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}
