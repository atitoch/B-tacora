import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/app_provider.dart';

class TaskTile extends StatelessWidget {
  final Task task;

  const TaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final theme = Theme.of(context);

    return Dismissible(
      key: Key('task_${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onError),
      ),
      onDismissed: (_) => provider.deleteTask(task.id!),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: task.completada
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        color: task.completada
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
            : null,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          leading: Checkbox(
            value: task.completada,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (_) => provider.toggleTask(task),
          ),
          title: Text(
            task.nombre,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              decoration:
                  task.completada ? TextDecoration.lineThrough : null,
              color: task.completada
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
