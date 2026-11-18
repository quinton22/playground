import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/match_model.dart';
import '../theme/app_colors.dart';

/// Card widget displaying a mutual match.
class MatchCard extends StatelessWidget {
  final MatchModel match;
  final String myHash;
  final bool showDate;

  const MatchCard({
    super.key,
    required this.match,
    required this.myHash,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final otherName = match.otherDisplayName(myHash);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0F5), Color(0xFFF3E5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated heart
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 26,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scaleXY(
                begin: 1.0,
                end: 1.1,
                duration: 700.ms,
                curve: Curves.easeInOut,
              )
              .then()
              .scaleXY(begin: 1.1, end: 1.0, duration: 700.ms),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$otherName was thinking of you! 💕',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  showDate
                      ? _formatDate(match.matchedAt)
                      : 'Today\'s match ✨',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onBackground.withOpacity(0.5),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(matchDay).inDays;

    if (diff == 0) return 'Today ✨';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
