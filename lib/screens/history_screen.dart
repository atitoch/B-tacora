import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/habit.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<AppProvider>().habits;

    if (habits.isEmpty) {
      return const Center(child: Text('Sin hábitos registrados.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: habits.length,
      itemBuilder: (ctx, i) => _HabitHistoryCard(habit: habits[i]),
    );
  }
}

class _HabitHistoryCard extends StatelessWidget {
  final Habit habit;

  const _HabitHistoryCard({required this.habit});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final historial = provider.historial14(habit);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              habit.nombre,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(14, (i) {
                final v = historial[i];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: _DayDot(value: v, daysAgo: 13 - i),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('14 días atrás',
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                Text('Hoy',
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final bool? value; // null = no aplica, true = completado, false = falló
  final int daysAgo;

  const _DayDot({required this.value, required this.daysAgo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (value == null) {
      return Container(
        height: 28,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            '—',
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    }

    final color = value! ? theme.colorScheme.primary : theme.colorScheme.error;

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: daysAgo == 0
            ? Border.all(color: color, width: 1.5)
            : null,
      ),
      child: Center(
        child: Icon(
          value! ? Icons.check : Icons.close,
          size: 14,
          color: color,
        ),
      ),
    );
  }
}
