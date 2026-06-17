import 'package:flutter/material.dart';

class StreakBadge extends StatelessWidget {
  final int racha;

  const StreakBadge({super.key, required this.racha});

  @override
  Widget build(BuildContext context) {
    if (racha == 0) return const SizedBox.shrink();

    final color = racha >= 7
        ? Colors.orange
        : racha >= 3
            ? Colors.amber
            : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            racha >= 3 ? '🔥' : '✦',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 3),
          Text(
            '$racha',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
