import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A slot showing either an empty placeholder or a filled "thinking of" entry.
class ThinkingSlot extends StatelessWidget {
  final int index;
  final String? targetHash;
  final VoidCallback? onRemove;

  const ThinkingSlot({
    super.key,
    required this.index,
    this.targetHash,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = targetHash == null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isEmpty ? AppColors.surface : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmpty ? AppColors.divider : AppColors.primaryLight,
          width: 1.5,
        ),
        boxShadow: isEmpty
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          // Heart icon / slot number
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isEmpty
                ? Container(
                    key: ValueKey('empty_$index'),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: AppColors.onBackground.withOpacity(0.3),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                : Container(
                    key: ValueKey('filled_$index'),
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: isEmpty
                ? Text(
                    'Tap + to add someone',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onBackground.withOpacity(0.35),
                          fontStyle: FontStyle.italic,
                        ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thinking of someone 💭',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.primary,
                                ),
                      ),
                      Text(
                        'Waiting for the match...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onBackground.withOpacity(0.5),
                            ),
                      ),
                    ],
                  ),
          ),
          if (!isEmpty && onRemove != null)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.primary.withOpacity(0.6),
                size: 20,
              ),
              onPressed: onRemove,
              tooltip: 'Remove',
            ),
        ],
      ),
    );
  }
}
