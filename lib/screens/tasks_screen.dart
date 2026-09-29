import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/task_tile.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final tasks = provider.tasks;

    return Column(
      children: [
        Expanded(
          child: tasks.isEmpty
              ? const Center(
                  child: Text(
                    'Sin tareas. Agrega lo que quieras hacer hoy.\nLas pendientes se mantienen hasta completarlas.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  buildDefaultDragHandles: false,
                  onReorder: context.read<AppProvider>().reorderTasks,
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) => TaskTile(
                    key: ValueKey(tasks[i].id),
                    task: tasks[i],
                    index: i,
                  ),
                ),
        ),
        _AddTaskBar(),
      ],
    );
  }
}

class _AddTaskBar extends StatefulWidget {
  @override
  State<_AddTaskBar> createState() => _AddTaskBarState();
}

class _AddTaskBarState extends State<_AddTaskBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  TimeOfDay? _hora;
  // Por defecto las tareas nuevas se mantienen hasta completarse.
  bool _persistente = true;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _hora = picked);
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final hora = _hora;
    _ctrl.clear();
    setState(() => _hora = null);
    _focus.requestFocus();
    try {
      await context
          .read<AppProvider>()
          .addTask(text, horaObjetivo: hora, persistente: _persistente);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar tarea: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chip de hora seleccionada (con recordatorio) para la nueva tarea.
          if (_hora != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InputChip(
                  avatar: const Icon(Icons.notifications_active_outlined,
                      size: 16),
                  label: Text('Recordar a las ${_hora!.format(context)}'),
                  onDeleted: () => setState(() => _hora = null),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Nueva tarea...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => setState(() => _persistente = !_persistente),
                tooltip: _persistente
                    ? 'Se mantiene hasta completarla'
                    : 'Solo para este día',
                icon: Icon(
                  _persistente ? Icons.event_repeat : Icons.today_outlined,
                  color: _persistente ? theme.colorScheme.primary : null,
                ),
              ),
              IconButton(
                onPressed: _pickTime,
                tooltip: 'Hora y recordatorio',
                icon: Icon(
                  _hora != null
                      ? Icons.access_time_filled
                      : Icons.access_time,
                  color: _hora != null ? theme.colorScheme.primary : null,
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: _submit,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
