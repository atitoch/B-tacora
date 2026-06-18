import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/app_provider.dart';
import 'streak_badge.dart';
import 'habit_form_dialog.dart';

class HabitTile extends StatelessWidget {
  final Habit habit;
  final int index;

  const HabitTile({super.key, required this.habit, required this.index});

  Future<void> _showEditDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final result = await showModalBottomSheet<Habit>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => HabitFormDialog(habit: habit),
    );
    if (result != null && context.mounted) {
      await provider.updateHabit(result);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar hábito'),
        content: Text('¿Eliminar "${habit.nombre}"? Se borrarán también sus registros.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await provider.deleteHabit(habit.id!);
    }
  }

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreakBadge(racha: racha),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onSelected: (v) {
                if (v == 'edit') _showEditDialog(context);
                if (v == 'delete') _confirmDelete(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Eliminar'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
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
