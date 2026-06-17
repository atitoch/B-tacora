import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import 'habits_screen.dart';
import 'tasks_screen.dart';
import 'history_screen.dart';

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

  Future<void> _showNoteDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final existing = provider.dailyNote;
    final textCtrl =
        TextEditingController(text: existing?.texto ?? '');
    int? energia = existing?.nivelEnergia;

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
              Text('Energía',
                  style: Theme.of(ctx).textTheme.labelMedium),
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
  }

  Future<void> _showExportDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final json = await provider.exportJson();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exportar datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Tus datos están listos. Copia el JSON o compártelo.'),
            const SizedBox(height: 12),
            Container(
              height: 180,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  json.length > 2000
                      ? '${json.substring(0, 2000)}\n\n... (${json.length} caracteres total)'
                      : json,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final fecha = DateFormat('EEE d MMM', 'es').format(provider.selectedDate);
    final esHoy = _isToday(provider.selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'B-tácora',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
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
          ],
        ),
        actions: [
          if (_tab == 0)
            IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Nota del día',
              onPressed: () => _showNoteDialog(context),
            ),
          PopupMenuButton(
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('Exportar datos'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (v) {
              if (v == 'export') _showExportDialog(context);
            },
          ),
        ],
      ),
      body: _screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: _tabs,
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}
