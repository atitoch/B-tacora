import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/app_provider.dart';

Color? _priorityColor(Prioridad p) {
  switch (p) {
    case Prioridad.alta:
      return Colors.red[600];
    case Prioridad.media:
      return Colors.orange[500];
    case Prioridad.baja:
      return Colors.blue[400];
    case Prioridad.ninguna:
      return null;
  }
}

String _priorityLabel(Prioridad p) {
  switch (p) {
    case Prioridad.alta:
      return 'Alta';
    case Prioridad.media:
      return 'Media';
    case Prioridad.baja:
      return 'Baja';
    case Prioridad.ninguna:
      return 'Sin prioridad';
  }
}

class TaskTile extends StatelessWidget {
  final Task task;
  final int index;

  const TaskTile({super.key, required this.task, required this.index});

  Future<void> _showEditDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final ctrl = TextEditingController(text: task.nombre);
    Prioridad selectedPrioridad = task.prioridad;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('Editar tarea'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Nombre',
                ),
                onSubmitted: (_) => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 16),
              Text('Prioridad',
                  style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: Prioridad.values.map((p) {
                  final color = _priorityColor(p);
                  final selected = selectedPrioridad == p;
                  return ChoiceChip(
                    label: Text(_priorityLabel(p)),
                    selected: selected,
                    avatar: color != null
                        ? CircleAvatar(
                            backgroundColor: color,
                            radius: 6,
                          )
                        : null,
                    onSelected: (_) =>
                        setModal(() => selectedPrioridad = p),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    final nombre = ctrl.text.trim();
    ctrl.dispose();

    if (confirmed == true && context.mounted) {
      if (nombre.isNotEmpty && nombre != task.nombre) {
        await provider.renameTask(task, nombre);
      }
      if (selectedPrioridad != task.prioridad) {
        await provider.setTaskPriority(task, selectedPrioridad);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Eliminar "${task.nombre}"?'),
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
      await provider.deleteTask(task.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final theme = Theme.of(context);
    final dotColor = _priorityColor(task.prioridad);

    return Card(
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
        title: Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: task.completada
                      ? dotColor.withValues(alpha: 0.4)
                      : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Flexible(
              child: Text(
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
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
