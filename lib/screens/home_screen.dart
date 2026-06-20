import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import '../providers/app_provider.dart';
import '../utils/date_utils.dart' as du;
import 'habits_screen.dart';
import 'tasks_screen.dart';
import 'history_screen.dart';
import '../widgets/habit_form_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  final _tabs = const [
    NavigationDestination(icon: Icon(Icons.repeat), label: 'Hábitos'),
    NavigationDestination(icon: Icon(Icons.checklist), label: 'Tareas'),
    NavigationDestination(
        icon: Icon(Icons.calendar_view_week_outlined), label: 'Historial'),
  ];

  final _screens = const [
    HabitsScreen(),
    TasksScreen(),
    HistoryScreen(),
  ];

  Future<void> _pickDate(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final now = DateTime.now();
    final minDate = now.subtract(Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: minDate,
      lastDate: now,
    );
    if (picked != null && context.mounted) {
      await provider.selectDate(picked);
    }
  }

  Future<void> _showNoteDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final existing = provider.dailyNote;
    final textCtrl = TextEditingController(text: existing?.texto ?? '');
    int? energia = existing?.nivelEnergia;

    try {
      await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nota del día',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: textCtrl,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '¿Cómo fue el día? ¿Qué bloqueó? ¿Qué funcionó?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Energía', style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                    5,
                    (i) => GestureDetector(
                          onTap: () => setModal(() => energia = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: energia == i + 1
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Theme.of(ctx)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: energia == i + 1
                                      ? Theme.of(ctx).colorScheme.onPrimary
                                      : null,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final texto = textCtrl.text.trim();
                    if (texto.isNotEmpty) {
                      await provider.saveDailyNote(texto, energia);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    } finally {
      textCtrl.dispose();
    }
  }

  Future<void> _showAddHabitDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const HabitFormDialog(),
    );
    if (result != null && context.mounted) {
      await provider.addHabit(result);
    }
  }

  /// Configura la anticipación (en minutos) de las notificaciones.
  Future<void> _showNotifSettings(BuildContext context) async {
    final provider = context.read<AppProvider>();
    const opciones = [0, 5, 10, 15, 30, 60];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final seleccion = provider.anticipacionMinutos;
            final theme = Theme.of(ctx);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notificaciones',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Anticipación: ¿cuántos minutos antes de la hora del '
                    'hábito o tarea quieres el aviso?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: opciones.map((min) {
                      final selected = seleccion == min;
                      return ChoiceChip(
                        label: Text(min == 0 ? 'A la hora' : '$min min antes'),
                        selected: selected,
                        onSelected: (_) async {
                          await provider.setAnticipacionMinutos(min);
                          setModal(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Listo'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Escribe el JSON a un archivo temporal y abre el share sheet del SO.
  Future<void> _exportData(BuildContext context) async {
    final provider = context.read<AppProvider>();
    // Capturar navigator y messenger antes de cualquier await para evitar
    // usar context después de que el widget pueda haberse desmontado.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final json = await provider.exportJson();
      final dir = await getTemporaryDirectory();
      final fecha = du.dateKey(DateTime.now());
      final file = File('${dir.path}/btacora_backup_$fecha.json');
      await file.writeAsString(json, flush: true);
      navigator.pop(); // cerrar spinner — siempre se ejecuta, mounted o no
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'B-tácora backup $fecha',
      );
    } catch (e) {
      navigator.pop(); // cerrar spinner
      messenger.showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final fecha = DateFormat('EEE d MMM', 'es').format(provider.selectedDate);
    final esHoy = du.isSameDay(provider.selectedDate, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _pickDate(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'B-tácora',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    esHoy ? 'Hoy, $fecha' : fecha,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (!esHoy)
            IconButton(
              icon: const Icon(Icons.today),
              tooltip: 'Ir a hoy',
              onPressed: () =>
                  context.read<AppProvider>().selectDate(DateTime.now()),
            ),
          if (_tab == 0)
            IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Nota del día',
              onPressed: () => _showNoteDialog(context),
            ),
          PopupMenuButton(
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'notif',
                child: ListTile(
                  leading: Icon(Icons.notifications_outlined),
                  title: Text('Notificaciones'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.ios_share_outlined),
                  title: Text('Exportar datos'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (v) {
              if (v == 'export') _exportData(context);
              if (v == 'notif') _showNotifSettings(context);
            },
          ),
        ],
      ),
      body: _screens[_tab],
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => _showAddHabitDialog(context),
              tooltip: 'Nuevo hábito',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: _tabs,
      ),
    );
  }
}
