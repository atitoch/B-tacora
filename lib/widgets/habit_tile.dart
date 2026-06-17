import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/app_provider.dart';
import 'streak_badge.dart';

class HabitTile extends StatelessWidget {
  final Habit habit;

  const HabitTile({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final log = provider.logDeHoy(habit.id!);
    final completado = log?.completado ?? false;
    final racha = provider.rachaActual(habit);
    final fallos = provider.rachaFallos(habit);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: completado
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      color: completado
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Checkbox(
          value: completado,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          onChanged: (v) => provider.toggleHabit(habit, v ?? false),
        ),
        title: Text(
          habit.nombre,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration: completado ? TextDecoration.lineThrough : null,
            color: completado
                ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                : null,
          ),
        ),
        subtitle: _buildSubtitle(context, theme, fallos),
        trailing: StreakBadge(racha: racha),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context, ThemeData theme, int fallos) {
    if (fallos >= 3) {
      return Text(
        'Llevas $fallos días sin esto',
        style: TextStyle(
          fontSize: 12,
          color: Colors.orange[700],
          fontWeight: FontWeight.w500,
        ),
      );
    }
    if (habit.horaObjetivo != null) {
      // Respeta la config de 12h/24h del dispositivo.
      final horaStr = habit.horaObjetivo!.format(context);
      return Text(
        horaStr,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }
    return null;
  }
}
